pragma solidity 0.4.24;

contract Sanity {

    string public name;
    uint256 private value;
    address public owner;
    uint256 private cancelCount;

    modifier  ownerOnly {
        if (msg.sender != owner) {
            revert();
        }
        _;
    }

    event NameChanged(address by, string to);
    event ValueChanged(uint256 value);

    constructor() public {
        name = "Kirobo";
        owner = msg.sender;
        value = 100;
    }

    function getValue() view public returns (uint256) {
        return value;
    }

    function setValue(uint256 _value) public ownerOnly {
        value = _value;
        emit ValueChanged(value);
    }

    function setName(string _name) public {
        name = _name;
        emit NameChanged(msg.sender, name);
    }

    function cancel() public {
        ++cancelCount;
        revert();
    }
}