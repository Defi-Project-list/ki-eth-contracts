pragma solidity 0.5.16;

contract Sender {
    function sendEther(address payable _to, uint256 _value) public {
        _to.transfer(_value);
    }
    function () external payable {}
}
