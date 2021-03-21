// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "../lib/StorageBase.sol";
import "../lib/Storage.sol";
import "./Storage2.sol";

contract Wallet2 is IStorage, StorageBase, Storage, Storage2 {

    event ValueChanged(uint256 newValue);

    function setValue(uint256 _value, uint256 _mul) public onlyOwner payable {
        value = _value * _mul;
        emit ValueChanged(value);
    }

    function getValue() public view returns (uint256) {
        return value;
    }

    // IStorage Implementation

    function migrate () external override onlyCreator() {
    }

    function version() public pure override returns (bytes8) {
        return bytes8("0.1");
    }

    function removeOwner() public {
        _owner = address(0);
    }

    function removeTarget() public {
        _target = address(0);
    }

}

