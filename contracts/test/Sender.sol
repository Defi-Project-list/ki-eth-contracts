// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

contract Sender {
    function sendEther(address payable _to, uint256 _value) public {
        _to.transfer(_value);
    }
    fallback () external payable {}
    receive () external payable {}
}
