pragma solidity 0.4.23;

import "./Backupable.sol";

contract Heritable is Backupable {

    struct Heir {
        address wallet;
        uint8   percent;
        bool    activated;
        bool    sent;
    }

    struct Inheritance {
        Heir[8] heirs;
        uint64  timeout;
        uint64  timestamp;
    }

    Inheritance private inheritance;

    constructor() public {
    }

    function getTotalPercent() view public returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < inheritance.heirs.length; i++) {
            total += inheritance.heirs[i].percent;
        }
        return total;
    }

    function setHeir (uint8 _slot, uint8 _percent, address _wallet) onlyOwner() public {
        require (_slot < 8);
        require (_wallet != address(0));
        Heir memory heir = Heir(_wallet, _percent, false, false);
        inheritance.heirs[_slot] = heir;
    }

    function removeHeir(uint8 _slot) onlyOwner() public {
        require (_slot < 8);
        Heir storage heir = inheritance.heirs[_slot];
        heir.wallet = address(0);
        heir.percent = 0;
        heir.activated = false;
        heir.sent = false;
    }

    function getHeir(uint256 _slot) view public returns (address, uint8 , bool, bool) {
        require (_slot < 8);
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
