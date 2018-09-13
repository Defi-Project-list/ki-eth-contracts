pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./Backupable.sol";

contract Heritable is Backupable {
    using SafeMath for uint256;

    event InheritanceActivated    (address indexed creator, address indexed activator, address[] wallets);
    event InheritanceChanged      (address indexed creator, address indexed owner, uint40 timeout, uint40 timestamp);
    event InheritanceRemoved      (address indexed creator, address indexed owner);
    event InheritanceHeirsChanged (address indexed creator, address indexed owner, address[] wallets, uint8[] percents);

    function setInheritance (uint32 _timeout) public onlyActiveOwner() {
        require (inheritance.activated == false, "inheritance.activated==false");

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

    function setHeirs (address[] _wallets, uint8[] _percents) public onlyActiveOwner() {
        require (inheritance.activated == false, "inheritance.activated==false");
        require (_wallets.length <= MAX_HEIRS, "_wallets.length<=MAX_HEIRS");
        require (_wallets.length == _percents.length, "_wallets.length==_percents.length");

        uint256 totalPercent = 0;
        for (uint256 i = 0; i < _wallets.length; ++i) {
            totalPercent += _percents[i];
            require(_wallets[i] != address(0), "_wallets[i]!=address(0)");
            require(_wallets[i] != address(this), "_wallets[i]!=address(this)");
        }
        require(totalPercent <= 100, "totalPercent<=100");

        for (i = 0; i < _wallets.length; ++i) {
            Heir storage heir = inheritance.heirs[i];
            if (heir.wallet != _wallets[i])     heir.wallet = _wallets[i];
            if (heir.percent != _percents[i])   heir.percent = _percents[i];
            if (heir.sent != false)             heir.sent = false;
        }
        if (i < MAX_HEIRS - 1) {
            heir = inheritance.heirs[i];
            if (heir.wallet != address(0)) heir.wallet = address(0);
        }

        // event related code starts here
        address[] memory wallets = new address[](i);
        uint8[] memory percents = new uint8[](i);
        for (uint256 inx = 0; inx < i; inx++) {
            heir = inheritance.heirs [inx];
            wallets[inx] = heir.wallet;
            percents[inx] = heir.percent;
        }
        emit InheritanceHeirsChanged(this.creator(), msg.sender, wallets, percents);
    }

    function getTotalPercent () public view returns (uint256 total) {
        for (uint256 i = 0; i < inheritance.heirs.length; i++) {
            if (inheritance.heirs[i].wallet == address(0)) {
                break;
            }
            total += inheritance.heirs[i].percent;
        }
        return total;
    }

    function getTotalTransfered () public view returns (uint256 total) {
        return totalTransfered;
    }

    function getHeirs () public view returns (bytes32[MAX_HEIRS] heirs) {
        for (uint256 i = 0; i < inheritance.heirs.length; i++) {
            Heir storage heir = inheritance.heirs [i];
            if (heir.wallet == address(0)) {
                break;
            }
            heirs[i] = bytes32 ((uint256(heir.wallet) << 96) + (uint256(heir.percent) << 88) + (heir.sent ? uint256(1) << 86 : 0));
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
        require (inheritance.enabled == true, "inheritance.enabled==true");
        require (inheritance.activated == false, "inheritance.activated==false");
        require (getInheritanceTimeLeft() == 0, "getInheritanceTimeLeft()==0");

        inheritance.activated = true;

        uint256 currentBalance = address(this).balance;
        for (uint256 i = 0; i < inheritance.heirs.length; i++) {
            Heir storage heir = inheritance.heirs [i];
            if (heir.wallet == address(0)){
                break;
            }
            if (heir.percent > 0) {
                // solium-disable-next-line security/no-send
                heir.sent = heir.wallet.send((currentBalance * heir.percent)/100);
            }
        }
        totalTransfered = currentBalance.sub(address(this).balance);

        // event related code starts here
        address[] memory wallets = new address[](i);
        for (uint256 inx = 0; inx < i; inx++) {
            heir = inheritance.heirs [inx];
            wallets[inx] = heir.wallet;
        }
        emit InheritanceActivated(this.creator(), msg.sender, wallets);
    }

}
