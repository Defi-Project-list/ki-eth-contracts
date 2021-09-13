// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v1;

contract Sender {
    function sendEther(address payable to, uint256 value) public {
        (bool success,) = to.call{value: value}("");
        require(success, "send failed");
    }

    fallback() external payable {}

    receive() external payable {}
}
