// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v1;

import "./StorageBase.sol";

contract ProxyLatest is StorageBase {
    receive() external payable {
        revert("should not accept ether directly");
    }

    fallback() external payable {
        address latest = ICreator(this.creator()).getLatestVersion();

        assembly {
            calldatacopy(0x00, 0x00, calldatasize())
            let res := delegatecall(gas(), latest, 0x00, calldatasize(), 0, 0)
            returndatacopy(0x00, 0x00, returndatasize())
            if res {
                return(0x00, returndatasize())
            }
            revert(0x00, returndatasize())
        }
    }
}
