// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v1;

import "../lib/StorageBase.sol";
import "../lib/Storage.sol";
import "./Storage2.sol";

contract Wallet2 is IStorage, StorageBase, Storage, Storage2 {
    event ValueChanged(uint256 newValue);

    function setValue(uint256 value, uint256 mul) public payable onlyOwner {
        s_value = value * mul;
        emit ValueChanged(s_value);
    }

    function getValue() public view returns (uint256) {
        return s_value;
    }

    // IStorage Implementation

    function migrate() external override onlyCreator() {}

    function version() public pure override returns (bytes8) {
        return bytes8("0.1");
    }

    function removeOwner() public {
        s_owner = address(0);
    }

    function removeTarget() public {
        s_target = address(0);
    }
}
