// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.6.11;

import "./StorageBase.sol";

contract Proxy is StorageBase {

   // receive () external payable {
   //     if (msg.value > 0) {
   //         emit GotEther(msg.sender, msg.value);
   //     }
   // }

   fallback () external payable {
        // solium-disable-next-line security/no-inline-assembly
        assembly {
                calldatacopy(0x00, 0x00, calldatasize())
                let res := delegatecall(gas(), sload(_target_slot), 0x00, calldatasize(), 0, 0)
                returndatacopy(0x00, 0x00, returndatasize())
                if res { return(0x00, returndatasize()) }
                revert(0x00, returndatasize())
            }
    }
}

