pragma solidity ^0.4.23;


import "./Backupable.sol";

contract Heritable is Backupable {

    uint256 constant private MAX_HEIRS = 4;

    struct Heir {
        address wallet;
        //address backup;
        uint8   percent;
        bool    activated;
        bool    sent;
    }

    struct Inheritance {
        Heir[MAX_HEIRS] heirs;
        uint64  timeout;
        uint64  timestamp;
    }

    Inheritance private inheritance;

    constructor() public {
    }

    function setHeirs (address[] _wallets, uint8[] _percents) public {
        require(_wallets.length <= MAX_HEIRS);
        require(_percents.length <= MAX_HEIRS);
        require(_wallets.length == _percents.length);
        uint256 totalPercent = 0;
        uint256 i = 0;
        for (i = 0; i < _percents.length; ++i) {
            totalPercent += _percents[i];
        }
        require(totalPercent <= 100);
        for (i = 0; i < MAX_HEIRS; ++i) {
            Heir storage heir = inheritance.heirs[i];
            if (i < _wallets.length) {
                heir.wallet = _wallets[i];
                heir.percent = _percents[i];
            }
            else {
                heir.wallet = address(0);
                heir.percent = 0;
            }

            heir.wallet = _wallets[i];
            heir.percent = _percents[i];
            heir.activated = false;
            heir.sent = false;
        }
    }

    function getTotalPercent() view public returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < inheritance.heirs.length; i++) {
            total += inheritance.heirs[i].percent;
        }
        return total;
    }

    function setHeir (uint8 _slot, uint8 _percent, address _wallet) public {
        require (_slot < MAX_HEIRS);
        require (_wallet != address(0));
        Heir memory heir = Heir(_wallet, _percent, false, false);
        inheritance.heirs[_slot] = heir;
    }

    function removeHeir(uint256 _slot) public {
        require (_slot < MAX_HEIRS);
        Heir storage heir = inheritance.heirs[_slot];
        heir.wallet = address(0);
        heir.percent = 0;
        heir.activated = false;
        heir.sent = false;
    }

    function getHeir(uint256 _slot) view public returns (address, uint8 , bool, bool) {
        require (_slot < MAX_HEIRS);
        Heir storage heir = inheritance.heirs [_slot];
        return (heir.wallet, heir.percent, heir.activated, heir.sent);
    }

    function activate () public {
        uint256 currentBalance = address(this).balance;
        for (uint256 i = 0; i < inheritance.heirs.length; i++) {
            Heir storage heir = inheritance.heirs [i];
            if (heir.percent > 0 && heir.activated == false) {
                heir.activated = true;
                // solium-disable-next-line security/no-send
                heir.sent = heir.wallet.send((currentBalance * heir.percent)/100);
            }
        }
    }

}
