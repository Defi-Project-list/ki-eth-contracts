pragma solidity 0.4.24;

contract Sender {
    function send(address _to, uint256 _value) public{
        _to.transfer(_value);
    }
    function () payable public {}
}
