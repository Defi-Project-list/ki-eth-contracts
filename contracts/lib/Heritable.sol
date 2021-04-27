// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v1;

// import "../../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./Backupable.sol";

abstract contract Heritable is Backupable {
    // using SafeMath for uint256;

    event InheritanceActivated    (address indexed creator, address indexed activator, address[] wallets);
    event InheritanceChanged      (address indexed creator, address indexed owner, uint40 timeout, uint40 timestamp);
    event InheritanceRemoved      (address indexed creator, address indexed owner);
    event InheritanceHeirsChanged (address indexed creator, address indexed owner, address[] wallets, uint16[] bps);
    event InheritancePayment      (address indexed creator, address indexed payee, uint256 amount, bool reward);

    function setInheritance (uint32 timeout) public onlyActiveOwner() {
        require (s_inheritance.activated == false, "inheritance activated");

        uint40 timestamp = getBlockTimestamp();

        if (s_inheritance.timeout != timeout)  s_inheritance.timeout = timeout;
        if (s_inheritance.enabled != true)      s_inheritance.enabled = true;
        s_inheritance.timestamp = timestamp;

        emit InheritanceChanged(this.creator(), msg.sender, timeout, timestamp);
    }

    function clearInheritance () public onlyActiveOwner() {
        emit InheritanceRemoved(this.creator(), msg.sender);

        if (s_inheritance.timeout != uint32(0)) s_inheritance.timeout = uint32(0);
        if (s_inheritance.enabled != false)     s_inheritance.enabled = false;
        if (s_inheritance.activated != false)   s_inheritance.activated = false;
        if (s_totalTransfered != 0)             s_totalTransfered = 0;

        for (uint256 i = 0; i < MAX_HEIRS; ++i) {
            Heir storage heir = s_inheritance.heirs [i];
            if (heir.wallet == payable(0)) {
                break;
            }
            if (heir.sent != false) heir.sent = false;
        }
    }

    function setHeirs (address payable[] memory wallets, uint16[] memory bps) public onlyActiveOwner() {
        require (s_inheritance.activated == false, "inheritance activated");
        require (wallets.length <= MAX_HEIRS, "too many heirs");
        require (wallets.length == bps.length, "heirs and bps don't match");

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
            if (sp_heir.wallet != wallets[i])      sp_heir.wallet = wallets[i];
            if (sp_heir.bps != bps[i])            sp_heir.bps = bps[i];
            if (sp_heir.sent != false)             sp_heir.sent = false;
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
        emit InheritanceHeirsChanged(this.creator(), msg.sender, walletList, bpsList);
    }

    function getTotalBPS () public view returns (uint256 total) {
        for (uint256 i = 0; i < s_inheritance.heirs.length; i++) {
            if (s_inheritance.heirs[i].wallet == address(0)) {
                break;
            }
            total += s_inheritance.heirs[i].bps;
        }
        return total;
    }

    function getTotalTransfered () public view returns (uint256 total) {
        return s_totalTransfered;
    }

    function getHeirs () public view returns (bytes32[MAX_HEIRS] memory heirs) {
        for (uint256 i = 0; i < s_inheritance.heirs.length; i++) {
            Heir storage sp_heir = s_inheritance.heirs[i];
            if (sp_heir.wallet == address(0)) {
                break;
            }
            heirs[i] = bytes32 ((uint256(uint160(address(sp_heir.wallet))) << 96) + (sp_heir.sent ? uint256(1) << 88 : 0) + (uint256(sp_heir.bps) << 72));
        }
    }

    function getInheritanceTimeLeft () public view returns (uint40 res) {
        uint40 timestamp = getBlockTimestamp();
        if (s_inheritance.timestamp > 0 && timestamp >= s_inheritance.timestamp && s_inheritance.timeout > timestamp - s_inheritance.timestamp
        ) {
            res = s_inheritance.timeout - (timestamp - s_inheritance.timestamp);
        }
    }

    function isInheritanceActivated () public view returns (bool) {
        return (s_inheritance.activated == true);
    }

    function isInheritanceEnabled () public view returns (bool) {
        return (s_inheritance.enabled == true);
    }

    function getInheritanceTimeout () public view returns (uint40) {
        return s_inheritance.timeout;
    }

    function getInheritanceTimestamp () public view returns (uint40) {
        return s_inheritance.timestamp;
    }

    function activateInheritance () public {
        require (s_inheritance.enabled == true, "inheritance is not enabled");
        require (s_inheritance.activated == false, "inheritance is activated");
        require (getInheritanceTimeLeft() == 0, "too early");

        s_inheritance.activated = true;

        uint256 currentBalance = address(this).balance;
        address payable payee = IOracle(ICreator(this.creator()).oracle()).paymentAddress();
        
        if (payee.send(currentBalance / 100)) {
          emit InheritancePayment (this.creator(), payee, currentBalance / 100, false);
        }

        payable(msg.sender).transfer(currentBalance / 1000);
        emit InheritancePayment (this.creator(), msg.sender, currentBalance / 1000, true);        

        currentBalance = address(this).balance;
        uint256 i;
        for (i = 0; i < s_inheritance.heirs.length; i++) {
            Heir storage sp_heir = s_inheritance.heirs[i];
            if (sp_heir.wallet == address(0)) {
                break;
            }
            if (sp_heir.bps > 0) {
                // solium-disable-next-line security/no-send
                sp_heir.sent = sp_heir.wallet.send((currentBalance * sp_heir.bps)/10000);
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

}
