// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v1;

contract Sanity {
    string public s_name;
    uint256 private s_value;
    address public s_owner;
    uint256 private s_cancelCount;

    modifier ownerOnly {
        if (msg.sender != s_owner) {
            revert();
        }
        _;
    }

    event NameChanged(address by, string to);
    event ValueChanged(uint256 value);

    constructor() {
        s_name = "Kirobo";
        s_owner = msg.sender;
        s_value = 100;
    }

    function getValue() public view returns (uint256) {
        return s_value;
    }

    function setValue(uint256 value) public ownerOnly {
        s_value = value;
        emit ValueChanged(value);
    }

    function setName(string memory name) public {
        s_name = name;
        emit NameChanged(msg.sender, name);
    }

    function cancel() public {
        ++s_cancelCount;
        revert();
    }
}
