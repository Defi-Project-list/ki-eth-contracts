pragma solidity 0.4.23;

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
        require (_percents.length <= MAX_HEIRS);
        require (_wallets.length == _percents.length);

        uint256 totalPercent = 0;
        for (uint256 i = 0; i < _percents.length; ++i) {
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

    function removeAllHeirs () onlyOwner() public {
        inheritance.heirs[0].wallet = address(0);
    }

    function getTotalPercent() view public returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < inheritance.heirs.length; i++) {
            if (inheritance.heirs[i].wallet == address(0)) {
                break;
            }
            total += inheritance.heirs[i].percent;
        }
        return total;
    }

    function getHeir(uint256 _slot) view public returns (address, uint8 , bool) {
        require (_slot < MAX_HEIRS);

        Heir storage heir = inheritance.heirs [_slot];

        if (heir.wallet != 0) {
            return (heir.wallet, heir.percent, heir.sent);
        }
        return (address(0), 0, false);
    }

    function getInheritanceTimeLeft () view public returns (uint64 _res) {
        if (getTouchTimestamp() + inheritance.timeout <= getBlockTimestamp()){
            _res = uint64(0);
        }
        else {
            _res = getTouchTimestamp() + inheritance.timeout - getBlockTimestamp();
        }
    }

    function inheritanceActivated () view public returns (bool) {
        return (inheritance.activated == true );
    }

    function inheritanceEnabled () view public returns (bool) {
        return (inheritance.enabled == true );
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
    }

}
