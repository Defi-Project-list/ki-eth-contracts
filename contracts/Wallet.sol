pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";

import "./lib/Heritable.sol";
import "./Trust.sol";

contract Wallet is IStorage, Heritable {
    using SafeMath for uint256;

    event SentEther  (address indexed creator, address indexed owner, address indexed to, uint256 value);

    function sendEther (address _to, uint256 _value) public onlyActiveOwner() {
        require (_value > 0, "value == 0");
        require (_value <= address(this).balance, "value > balance");
        emit SentEther (this.creator(), owner, _to, _value);
        _to.transfer (_value);
    }

    function getBalance () public view returns (uint256) {
        return address(this).balance;
    }

    /*
    function createTrust(address _wallet, uint40 _start, uint32 _period, uint16 _times, uint256 _amount, bool _cancelable) payable public {
        require(trust == Trust(0));
        trust = (new Trust).value(_amount.mul(_times))(_wallet, _start, _period, _times, _amount, _cancelable);
    }

    function destroyTrust() public {
        require(trust != Trust(0));
        trust.destroy();
        trust = Trust(0);
    }

    function getTrust() public view returns (Trust) {
        return trust;
    }
    */

    // IStorage Implementation
    function migrate () external onlyCreator()  {
    }

    function version() public pure returns (bytes8){
        return bytes8("1.1.2");
    }

}
