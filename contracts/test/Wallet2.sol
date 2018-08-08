pragma solidity 0.4.24;

import "../lib/StorageBase.sol";
import "../lib/Storage.sol";
import "./Storage2.sol";

contract Wallet2 is IStorage, StorageBase, Storage, Storage2 {

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

