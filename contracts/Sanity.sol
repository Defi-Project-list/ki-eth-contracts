pragma solidity ^0.4.19;

contract  Sanity {

    string public name;
    uint256 private value;
    address public owner;

    modifier  OwnerOnly { 
        if (msg.sender != owner) {
            revert();
        }
        _;
    }

    event NameChanged(address by, string to);
    event ValueChanged(uint256 value);

    function  Sanity() public {
        name = "Kirobo";
        owner = msg.sender;
        value = 100;
    }

    function getValue() view public returns (uint256) {
        return value;
    }

    function setValue(uint256 _value) public OwnerOnly {
        value = _value;
        ValueChanged(value);
    }

    function setName(string _name) public {
        name = _name;
        NameChanged(msg.sender, name);
    }
}
