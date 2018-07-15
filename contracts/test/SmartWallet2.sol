pragma solidity 0.4.24;

import "../lib/SW_Storage.sol";

contract SmartWallet2 is SW_Storage {

    uint256 value;

    event ValueChanged(uint256 newValue);

    function setValue(uint256 _value, uint256 _mul) public payable {
        value = _value * _mul;
        emit ValueChanged(value);
    }

    function getValue() view public returns (uint256) {
        return value;
    }

}

