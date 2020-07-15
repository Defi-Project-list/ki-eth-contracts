// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.6.11;

import "./StorageBase.sol";

contract ProxyLatest is StorageBase {

    fallback () external payable {
        address latest = ICreator(this.creator()).getLatestVersion();
        // solium-disable-next-line security/no-inline-assembly
        assembly {
                calldatacopy(0x00, 0x00, calldatasize())
                let res := delegatecall(gas(), latest, 0x00, calldatasize(), 0, 0)
                returndatacopy(0x00, 0x00, returndatasize())
                if res { return(0x00, returndatasize()) }
                revert(0x00, returndatasize())
            }
    }
}

