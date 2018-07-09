pragma solidity 0.4.24;

import "./SWStorageBase.sol";

contract SmartWallet is SWStorageBase {

    uint256 value;

    function setValue(uint256 _value) public {
        value = _value;
    }

    function getValue() view public returns (uint256) {
        return value;
    }

}

