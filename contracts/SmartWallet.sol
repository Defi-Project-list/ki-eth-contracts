pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";

import "./lib/SW_Heritable.sol";
import "./SW_Trust.sol";

contract SmartWallet is SW_Heritable {
    using SafeMath for uint256;

    //uint256 public passCount;

    event SentEther  (address indexed creator, address indexed owner, address indexed to, uint256 value);
    //event PassCalled (address indexed from);

    function sendEther (address _to, uint256 _value) public onlyActiveOwner() {
        require (_value > 0, "value == 0");
        require (_value <= address(this).balance, "value > balance");
        emit SentEther (this.creator(), owner, _to, _value);
        _to.transfer (_value);
    }

    function getBalance () view public returns (uint256) {
        return address(this).balance;
    }

    SW_Trust private trust;

    function createTrust(address _wallet, uint40 _start, uint32 _period, uint16 _times, uint256 _amount, bool _cancelable) payable public {
        require(trust == SW_Trust(0));
        trust = (new SW_Trust).value(_amount.mul(_times))(_wallet, _start, _period, _times, _amount, _cancelable);
    }

    function destroyTrust() public {
        require(trust != SW_Trust(0));
        trust.destroy();
        trust = SW_Trust(0);
    }

    function getTrust() public view returns (SW_Trust) {
        return trust;
    }

    function version() pure public returns (bytes8){
        return bytes8("1.1");
    }
    //function pass () public {
    //    emit PassCalled (msg.sender);
    //    ++passCount;
    //}
}
