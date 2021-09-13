// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v1;

import "./Backupable.sol";

/** @title Heritable contract
    @author Tal Asa <tal@kirobo.io>
    @notice Heritable contract intreduces a way to set up heirs to the 
            funds in a specific wallet. 
            Features:
            1. the contract supports up to 8 heirs
            2. abillity to set a time (in seconds) that the funds will be sent to the heirs. 
 */
abstract contract Heritable is Backupable {
    uint256 internal constant MAX_HEIRS = 8;
    struct Heir {
        address payable wallet;
        bool sent;
        uint16 bps;
        uint72 filler;
    }

    struct Inheritance {
        Heir[MAX_HEIRS] heirs;
        uint40 timeout;
        bool enabled;
        bool activated;
        uint40 timestamp;
        uint16 filler;
    }

    Inheritance internal s_inheritance;
    uint256 internal s_totalTransfered;

    event InheritanceActivated(
        address indexed creator,
        address indexed activator,
        address[] wallets
    );
    event InheritanceChanged(
        address indexed creator,
        address indexed owner,
        uint40 timeout,
        uint40 timestamp
    );
    event InheritanceRemoved(address indexed creator, address indexed owner);
    event InheritanceHeirsChanged(
        address indexed creator,
        address indexed owner,
        address[] wallets,
        uint16[] bps
    );
    event InheritancePayment(
        address indexed creator,
        address indexed payee,
        uint256 amount,
        bool reward
    );

    /** @notice setInheritance
                the function sets the time conditions for the inheritance
        @param timeout (uint32) - hold the block timeStamp and the timeout is set from that time
     */
    function setInheritance(uint32 timeout) external onlyActiveOwner() {
        require(s_inheritance.activated == false, "inheritance activated");

        uint40 timestamp = getBlockTimestamp();

        if (s_inheritance.timeout != timeout) s_inheritance.timeout = timeout;
        if (s_inheritance.enabled != true) s_inheritance.enabled = true;
        s_inheritance.timestamp = timestamp;

        emit InheritanceChanged(this.creator(), msg.sender, timeout, timestamp);
    }

    /** @notice clearInheritance
                the function removes the heir list asociated with a apecific wallet
                resets the timeOut and unactivates the inharitance process from the wallet owner
     */
    function clearInheritance() external onlyActiveOwner() {
        emit InheritanceRemoved(this.creator(), msg.sender);

        if (s_inheritance.timeout != uint32(0))
            s_inheritance.timeout = uint32(0);
        if (s_inheritance.enabled != false) s_inheritance.enabled = false;
        if (s_inheritance.activated != false) s_inheritance.activated = false;
        if (s_totalTransfered != 0) s_totalTransfered = 0;

        for (uint256 i = 0; i < MAX_HEIRS; ++i) {
            Heir storage heir = s_inheritance.heirs[i];
            if (heir.wallet == payable(0)) {
                break;
            }
            if (heir.sent != false) heir.sent = false;
        }
    }

    /** @notice setHeir - as the name suggests, the function sets the heirs to a specific wallet
        @param wallets - address payable[] - an array of wallets, one for each heir
        @param bps     - uint16[] - an array of funds for each heir (bps => 0.01%)
        @dev            the function emits an event called InheritanceHeirsChanged with the
                        new heirs wallets and funds
     */
    function setHeirs(address payable[] memory wallets, uint16[] memory bps)
        external
        onlyActiveOwner()
    {
        require(s_inheritance.activated == false, "inheritance activated");
        require(wallets.length <= MAX_HEIRS, "too many heirs");
        require(wallets.length == bps.length, "heirs and bps don't match");

        uint256 totalBPS = 0;
        uint256 i;
        for (i = 0; i < wallets.length; ++i) {
            totalBPS += bps[i];
            require(wallets[i] != address(0), "no heir");
            require(wallets[i] != address(this), "current contract is heir");
        }
        require(totalBPS <= 10000, "total>100%");

        for (i = 0; i < wallets.length; ++i) {
            Heir storage sp_heir = s_inheritance.heirs[i];
            if (sp_heir.wallet != wallets[i]) sp_heir.wallet = wallets[i];
            if (sp_heir.bps != bps[i]) sp_heir.bps = bps[i];
            if (sp_heir.sent != false) sp_heir.sent = false;
        }
        if (i < MAX_HEIRS - 1) {
            Heir storage sp_heir = s_inheritance.heirs[i];
            if (sp_heir.wallet != payable(0)) sp_heir.wallet = payable(0);
        }

        // event related code starts here
        address[] memory walletList = new address[](i);
        uint16[] memory bpsList = new uint16[](i);
        for (uint256 inx = 0; inx < i; inx++) {
            Heir storage sp_heir = s_inheritance.heirs[inx];
            walletList[inx] = sp_heir.wallet;
            bpsList[inx] = sp_heir.bps;
        }
        emit InheritanceHeirsChanged(
            this.creator(),
            msg.sender,
            walletList,
            bpsList
        );
    }

    /** @notice activateInheritance function check if all the necessary measures have been fufilled
                and then sends the funds defined to the heirs wallets
     */
    function activateInheritance() external {
        require(s_inheritance.enabled, "inheritance is not enabled");
        require(s_inheritance.activated == false, "inheritance is activated");
        require(getInheritanceTimeLeft() == 0, "too early");

        s_inheritance.activated = true;

        uint256 currentBalance = address(this).balance;
        address payable payee = IOracle(ICreator(this.creator()).oracle())
        .paymentAddress();

        (bool paymentOK,) = payee.call{value: currentBalance/100, gas: CALL_GAS}("");
        if (paymentOK) {
            emit InheritancePayment(
                this.creator(),
                payee,
                currentBalance / 100,
                false
            );
        }

        (bool sentToActivatorOK,) = payable(msg.sender).call{value: currentBalance/1000, gas: CALL_GAS}("");
        if (sentToActivatorOK) {
            emit InheritancePayment(
                this.creator(),
                msg.sender,
                currentBalance / 1000,
                true
            );
        }

        currentBalance = address(this).balance;
        uint256 i;
        for (i = 0; i < s_inheritance.heirs.length; i++) {
            Heir storage sp_heir = s_inheritance.heirs[i];
            if (sp_heir.wallet == address(0)) {
                break;
            }
            if (sp_heir.bps > 0) {
                (bool sentHairOK,) = sp_heir.wallet.call{value: (currentBalance * sp_heir.bps) / 10000, gas: CALL_GAS}("");
                sp_heir.sent = sentHairOK;
            }
        }
        s_totalTransfered = currentBalance - address(this).balance;

        // event related code starts here
        address[] memory wallets = new address[](i);
        for (uint256 inx = 0; inx < i; inx++) {
            Heir storage sp_heir = s_inheritance.heirs[inx];
            wallets[inx] = sp_heir.wallet;
        }
        emit InheritanceActivated(this.creator(), msg.sender, wallets);
    }

    /** @notice getTotalBPS - calculates and returns the total bps (1 bps = 0.01%) sets to be sent
                once the inheritance will take effect
        @return total (uint256) 
     */
    function getTotalBPS() external view returns (uint256 total) {
        for (uint256 i = 0; i < s_inheritance.heirs.length; i++) {
            if (s_inheritance.heirs[i].wallet == address(0)) {
                break;
            }
            total += s_inheritance.heirs[i].bps;
        }
        return total;
    }

    function getTotalTransfered() external view returns (uint256 total) {
        return s_totalTransfered;
    }

    /** @notice getHeirs - get the heir list as a bytes32 array
        @return heirs (bytes32[MAX_HEIRS])
     */
    function getHeirs()
        external
        view
        returns (bytes32[MAX_HEIRS] memory heirs)
    {
        for (uint256 i = 0; i < s_inheritance.heirs.length; i++) {
            Heir storage sp_heir = s_inheritance.heirs[i];
            if (sp_heir.wallet == address(0)) {
                break;
            }
            heirs[i] = bytes32(
                (uint256(uint160(address(sp_heir.wallet))) << 96) +
                    (sp_heir.sent ? uint256(1) << 88 : 0) +
                    (uint256(sp_heir.bps) << 72)
            );
        }
    }

    function isInheritanceActivated() external view returns (bool) {
        return (s_inheritance.activated);
    }

    function isInheritanceEnabled() external view returns (bool) {
        return (s_inheritance.enabled);
    }

    function getInheritanceTimeout() external view returns (uint40) {
        return s_inheritance.timeout;
    }

    function getInheritanceTimestamp() external view returns (uint40) {
        return s_inheritance.timestamp;
    }

    /** @notice getInheritanceTimeLeft - checks the time left until the inheritance can be activated
        @return res (uint40) - time left in seconds untill the inheritance is enabled or 0
                    if the time has passed
    */
    function getInheritanceTimeLeft() public view returns (uint40 res) {
        uint40 timestamp = getBlockTimestamp();
        if (
            s_inheritance.timestamp > 0 &&
            timestamp >= s_inheritance.timestamp &&
            s_inheritance.timeout > timestamp - s_inheritance.timestamp
        ) {
            res = s_inheritance.timeout - (timestamp - s_inheritance.timestamp);
        }
    }
}
