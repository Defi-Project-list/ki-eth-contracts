// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v1;

contract Sender {
    function sendEther(address payable to, uint256 value) public {
        to.transfer(value);
    }

    fallback() external payable {}

    receive() external payable {}
}
