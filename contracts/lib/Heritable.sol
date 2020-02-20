pragma solidity 0.5.16;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./Backupable.sol";

contract Heritable is Backupable {
    using SafeMath for uint256;

    event InheritanceActivated    (address indexed creator, address indexed activator, address[] wallets);
    event InheritanceChanged      (address indexed creator, address indexed owner, uint40 timeout, uint40 timestamp);
    event InheritanceRemoved      (address indexed creator, address indexed owner);
    event InheritanceHeirsChanged (address indexed creator, address indexed owner, address[] wallets, uint16[] bps);

    function setInheritance (uint32 _timeout) public onlyActiveOwner() {
        require (inheritance.activated == false, "inheritance activated");

        uint40 timestamp = getBlockTimestamp();

        if (inheritance.timeout != _timeout)  inheritance.timeout = _timeout;
        if (inheritance.enabled != true)      inheritance.enabled = true;
        inheritance.timestamp = timestamp;

        emit InheritanceChanged(this.creator(), msg.sender, _timeout, timestamp);
    }

    function clearInheritance () public onlyActiveOwner() {
        emit InheritanceRemoved(this.creator(), msg.sender);

        if (inheritance.timeout != uint32(0)) inheritance.timeout = uint32(0);
        if (inheritance.enabled != false)     inheritance.enabled = false;
        if (inheritance.activated != false)   inheritance.activated = false;
        if (totalTransfered != 0)             totalTransfered = 0;

        for (uint256 i = 0; i < MAX_HEIRS; ++i) {
            Heir storage heir = inheritance.heirs [i];
            if (heir.wallet == address(0)) {
                break;
            }
            if (heir.sent != false) heir.sent = false;
        }
    }

    function setHeirs (address payable[] memory _wallets, uint16[] memory _bps) public onlyActiveOwner() {
        require (inheritance.activated == false, "inheritance activated");
        require (_wallets.length <= MAX_HEIRS, "too many heirs");
        require (_wallets.length == _bps.length, "heirs and bps don't match");

        uint256 totalBPS = 0;
        uint256 i;
        for (i = 0; i < _wallets.length; ++i) {
            totalBPS += _bps[i];
            require(_wallets[i] != address(0), "no heir");
            require(_wallets[i] != address(this), "current contract is heir");
        }
        require(totalBPS <= 10000, "total>100%");

        for (i = 0; i < _wallets.length; ++i) {
            Heir storage heir = inheritance.heirs[i];
            if (heir.wallet != _wallets[i])     heir.wallet = _wallets[i];
            if (heir.bps != _bps[i])   heir.bps = _bps[i];
            if (heir.sent != false)             heir.sent = false;
        }
        if (i < MAX_HEIRS - 1) {
            Heir storage heir = inheritance.heirs[i];
            if (heir.wallet != address(0)) heir.wallet = address(0);
        }

        // event related code starts here
        address[] memory wallets = new address[](i);
        uint16[] memory bps = new uint16[](i);
        for (uint256 inx = 0; inx < i; inx++) {
            Heir storage heir = inheritance.heirs [inx];
            wallets[inx] = heir.wallet;
            bps[inx] = heir.bps;
        }
        emit InheritanceHeirsChanged(this.creator(), msg.sender, wallets, bps);
    }

    function getTotalBPS () public view returns (uint256 total) {
        for (uint256 i = 0; i < inheritance.heirs.length; i++) {
            if (inheritance.heirs[i].wallet == address(0)) {
                break;
            }
            total += inheritance.heirs[i].bps;
        }
        return total;
    }

    function getTotalTransfered () public view returns (uint256 total) {
        return totalTransfered;
    }

    function getHeirs () public view returns (bytes32[MAX_HEIRS] memory heirs) {
        for (uint256 i = 0; i < inheritance.heirs.length; i++) {
            Heir storage heir = inheritance.heirs [i];
            if (heir.wallet == address(0)) {
                break;
            }
            heirs[i] = bytes32 ((uint256(heir.wallet) << 96) + (heir.sent ? uint256(1) << 88 : 0) + (uint256(heir.bps) << 72));
        }
    }

    function getInheritanceTimeLeft () public view returns (uint40 _res) {
        uint40 _timestamp = getBlockTimestamp();
        if (inheritance.timestamp > 0 && _timestamp >= inheritance.timestamp && inheritance.timeout > _timestamp - inheritance.timestamp
        ) {
            _res = inheritance.timeout - (_timestamp - inheritance.timestamp);
        }
    }

    function isInheritanceActivated () public view returns (bool) {
        return (inheritance.activated == true);
    }

    function isInheritanceEnabled () public view returns (bool) {
        return (inheritance.enabled == true);
    }

    function getInheritanceTimeout () public view returns (uint40) {
        return inheritance.timeout;
    }

    function getInheritanceTimestamp () public view returns (uint40) {
        return inheritance.timestamp;
    }

    function activateInheritance () public {
        require (inheritance.enabled == true, "inheritance is not enabled");
        require (inheritance.activated == false, "inheritance is activated");
        require (getInheritanceTimeLeft() == 0, "too early");

        inheritance.activated = true;

        uint256 currentBalance = address(this).balance;
        uint256 i;
        for (i = 0; i < inheritance.heirs.length; i++) {
            Heir storage heir = inheritance.heirs [i];
            if (heir.wallet == address(0)){
                break;
            }
            if (heir.bps > 0) {
                // solium-disable-next-line security/no-send
                heir.sent = heir.wallet.send((currentBalance * heir.bps)/10000);
            }
        }
        totalTransfered = currentBalance.sub(address(this).balance);

        // event related code starts here
        address[] memory wallets = new address[](i);
        for (uint256 inx = 0; inx < i; inx++) {
            Heir storage heir = inheritance.heirs [inx];
            wallets[inx] = heir.wallet;
        }
        emit InheritanceActivated(this.creator(), msg.sender, wallets);
    }

}
