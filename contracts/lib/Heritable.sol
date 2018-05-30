pragma solidity 0.4.24;

import "./Backupable.sol";

contract Heritable is Backupable {

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

    Inheritance private inheritance;

    event InheritanceActivated (address indexed activator, address[] wallets);

    constructor() Backupable () public {
    }

    function setInheritance (uint64 _timeout) onlyOwner() public {
        _touch();
        require (inheritance.activated == false);
        if (inheritance.timeout != _timeout) {
            inheritance.timeout = _timeout;
        }
        if (inheritance.enabled != true) {
            inheritance.enabled = true;
        }
    }

    function clearInheritance () onlyOwner() public {
        inheritance.timeout = 0;
        inheritance.enabled = false;
        inheritance.activated = false;
        for (uint256 i = 0; i < MAX_HEIRS; ++i) {
            Heir storage heir = inheritance.heirs [i];
            if (heir.wallet == address(0)) {
                break;
            }
            if (heir.sent == true) {
                heir.sent = false;
            }
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
            if (heir.wallet != _wallets[i]) {
                heir.wallet = _wallets[i];
            }
            if (heir.percent != _percents[i]) {
                heir.percent = _percents[i];
            }
            if (heir.sent) {
                heir.sent = false;
            }
        }
        if (i < MAX_HEIRS - 1) {
            heir = inheritance.heirs[i];
            if (heir.wallet != address(0)) {
                heir.wallet = 0;
            }
        }
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
        if (getTouchTimestamp() + inheritance.timeout <= getBlockTimestamp()){
            _res = uint64(0);
        }
        else {
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
