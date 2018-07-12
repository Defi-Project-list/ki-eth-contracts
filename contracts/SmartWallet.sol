pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";

import "./lib/SWHeritable.sol";
import "./SWTrust.sol";

contract SmartWallet is SWHeritable {
    using SafeMath for uint256;

    //uint256 public passCount;

    event SentEther  (address indexed to, uint256 value);
    //event PassCalled (address indexed from);

    function sendEther (address _to, uint256 _value) public onlyActiveOwner() {
        require (_value > 0, "value == 0");
        require (_value <= address(this).balance, "value > balance");
        emit SentEther (_to, _value);
        _to.transfer (_value);
    }

    function getBalance () view public returns (uint256) {
        return address(this).balance;
    }

    SWTrust private trust;

    function createTrust(address _wallet, uint40 _start, uint32 _period, uint16 _times, uint256 _amount, bool _cancelable) payable public {
        require(trust == SWTrust(0));
        trust = (new SWTrust).value(_amount.mul(_times))(_wallet, _start, _period, _times, _amount, _cancelable);
    }

    function destroyTrust() public {
        require(trust != SWTrust(0));
        trust.destroy();
        trust = SWTrust(0);
    }

    function getTrust() public view returns (SWTrust) {
        return trust;
    }

    //function pass () public {
    //    emit PassCalled (msg.sender);
    //    ++passCount;
    //}
}
