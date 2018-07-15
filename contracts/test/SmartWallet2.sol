pragma solidity 0.4.24;

import "../lib/SW_Storage.sol";

contract SmartWallet2 is SW_Storage {

    uint256 value;

    function setValue(uint256 _value, uint256 _mul) public {
        value = _value * _mul;
    }

    function getValue() view public returns (uint256) {
        return value;
    }

}

