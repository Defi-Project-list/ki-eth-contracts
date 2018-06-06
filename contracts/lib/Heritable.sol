pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./Backupable.sol";

contract Heritable is Backupable {
    using SafeMath for uint256;

    uint256 constant private MAX_HEIRS = 8;

    struct Heir {
        address wallet;
        uint8   percent;
        bool    sent;
    }

    struct Inheritance {
        Heir[MAX_HEIRS] heirs;
        uint64  timeout;
        bool    enabled;
        bool    activated;
    }

    uint256 private totalTransfered;
    Inheritance private inheritance;

    event InheritanceActivated    (address indexed activator, address[] wallets);
    event InheritanceChanged      (address indexed owner, uint64 timeout);
    event InheritanceRemoved      (address indexed owner);
    event InheritanceHeirsChanged (address indexed owner, address[] wallets, uint64[] percents);

    constructor() Backupable () public {
    }

    function setInheritance (uint64 _timeout) onlyOwner() public {
        _touch();
        require (inheritance.activated == false);

        emit InheritanceChanged(msg.sender, _timeout);

        if (inheritance.timeout != _timeout)  inheritance.timeout = _timeout;
        if (inheritance.enabled != true)      inheritance.enabled = true;
    }

    function clearInheritance () onlyOwner() public {
        emit InheritanceRemoved(msg.sender);

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

    function setHeirs (address[] _wallets, uint8[] _percents) onlyOwner() public {
        require (inheritance.activated == false);
        require (_wallets.length <= MAX_HEIRS);
        require (_wallets.length == _percents.length);

        uint256 totalPercent = 0;
        for (uint256 i = 0; i < _wallets.length; ++i) {
            totalPercent += _percents[i];
            require(_wallets[i] != address(0));
            require(_wallets[i] != address(this));
        }
        require(totalPercent <= 100);

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
        uint64[] memory percents = new uint64[](i);
        for (uint256 inx = 0; inx < i; inx++) {
            heir = inheritance.heirs [inx];
            wallets[inx] = heir.wallet;
            percents[inx] = heir.percent;
        }
        emit InheritanceHeirsChanged(msg.sender, wallets, percents);
    }

    function getTotalPercent () view public returns (uint256 total) {
        for (uint256 i = 0; i < inheritance.heirs.length; i++) {
            if (inheritance.heirs[i].wallet == address(0)) {
                break;
            }
            total += inheritance.heirs[i].percent;
        }
        return total;
    }

    function getTotalTransfered () view public returns (uint256 total) {
        return totalTransfered;
    }

    function getHeirs () view public returns (bytes32[MAX_HEIRS] heirs) {
        for (uint256 i = 0; i < inheritance.heirs.length; i++) {
            Heir storage heir = inheritance.heirs [i];
            if (heir.wallet == address(0)) {
                break;
            }
            heirs[i] = bytes32 ((uint256(heir.wallet) << 96) + (uint256(heir.percent) << 88) + (heir.sent ? uint256(1) << 86 : 0));
        }
    }

    function getInheritanceTimeLeft () view public returns (uint64 _res) {
        if (getTouchTimestamp() + inheritance.timeout > getBlockTimestamp()){
            _res = getTouchTimestamp() + inheritance.timeout - getBlockTimestamp();
        }
    }

    function isInheritanceActivated () view public returns (bool) {
        return (inheritance.activated == true);
    }

    function isInheritanceEnabled () view public returns (bool) {
        return (inheritance.enabled == true);
    }

    function getInheritanceTimeout () view public returns (uint64) {
        return inheritance.timeout;
    }

    function activateInheritance () public {
        require (inheritance.enabled == true);
        require (inheritance.activated == false);
        require (getInheritanceTimeLeft() == 0);

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
        emit InheritanceActivated(msg.sender, wallets);
    }

    function () payable public {
    }

}
