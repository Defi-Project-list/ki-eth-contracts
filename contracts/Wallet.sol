pragma solidity 0.4.24;

import "./lib/Heritable.sol";
import "./Trust.sol";

contract Wallet is Heritable {
    uint256 public passCount;
    Trust public trust;

    event GotEther   (address indexed from, uint256 value);
    event SentEther  (address indexed to, uint256 value);
    event PassCalled (address indexed from);

    modifier logPayment {
        if (msg.value > 0) {
            emit GotEther(msg.sender, msg.value);
        }
        _;
    }

    constructor () Heritable () payable logPayment() public {
    }

    function sendEther (address _to, uint256 _value) public onlyActiveOwner() {
        require (_value > 0, "value == 0");
        require (_value <= address(this).balance, "value > balance");
        emit SentEther (_to, _value);
        _to.transfer (_value);
    }

    function getBalance () view public returns (uint256) {
        return address(this).balance;
    }

    Trust private trust;

    function createTrust(address _wallet, uint40 _start, uint32 _period, uint16 _times, uint256 _amount, bool _cancelable) payable public {
        require(trust == Trust(0));
        trust = (new Trust).value(msg.value)(_wallet, _start, _period, _times, _amount, _cancelable);
    }

    function destroyTrust() public {
        require(trust != Trust(0));
        trust.destroy();
        trust = Trust(0);
    }

    function getTrust() public view returns (Trust) {
        return trust;
    }

    function pass () public {
        emit PassCalled (msg.sender);
        ++passCount;
    }

    function () payable logPayment() public {
    }
}
