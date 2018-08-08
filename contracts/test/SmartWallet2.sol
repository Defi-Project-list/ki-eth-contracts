pragma solidity 0.4.24;

import "../lib/SW_StorageBase.sol";
import "../lib/SW_Storage.sol";
import "./SW_Storage2.sol";

contract SmartWallet2 is IStorage, SW_StorageBase, SW_Storage, SW_Storage2 {

    event ValueChanged(uint256 newValue);


    function setValue(uint256 _value, uint256 _mul) public payable {
        value = _value * _mul;
        emit ValueChanged(value);
    }

    function getValue() view public returns (uint256) {
        return value;
    }

    // IStorage Implementation

    function migrate () external onlyCreator()  {
    }

    function version() pure public returns (bytes8){
        return bytes8("0.1");
    }

}

