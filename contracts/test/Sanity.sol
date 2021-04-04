// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v1;

contract Sanity {
    string public name;
    uint256 private value;
    address public owner;
    uint256 private cancelCount;

    modifier ownerOnly {
        if (msg.sender != owner) {
            revert();
        }
        _;
    }

    event NameChanged(address by, string to);
    event ValueChanged(uint256 value);

    constructor() {
        name = "Kirobo";
        owner = msg.sender;
        value = 100;
    }

    function getValue() public view returns (uint256) {
        return value;
    }

    function setValue(uint256 _value) public ownerOnly {
        value = _value;
        emit ValueChanged(value);
    }

    function setName(string memory _name) public {
        name = _name;
        emit NameChanged(msg.sender, name);
    }

    function cancel() public {
        ++cancelCount;
        revert();
    }
}
