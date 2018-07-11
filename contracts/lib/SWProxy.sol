pragma solidity 0.4.24;

import "./SWStorageBase.sol";

contract SWProxy is SWStorageBase {

    function () payable public {
        // solium-disable-next-line security/no-inline-assembly
        assembly {
                calldatacopy(0x00, 0x00, calldatasize)
                let res := delegatecall(gas, sload(target_slot), 0x00, calldatasize, 0, 0)
                returndatacopy(0x00, 0x00, returndatasize)
                if res { return(0x00, returndatasize) }
                revert(0x00, returndatasize)
            }

        /*
        bytes memory data = msg.data;
        address impl = target;
            // solium-disable-next-line security/no-inline-assembly
        assembly {
                let result := delegatecall(gas, impl, add(data, 0x20), mload(data), 0, 0)
                let size := returndatasize
                let ptr := mload(0x40)
                returndatacopy(ptr, 0, size)
                switch result
                case 0 { revert(ptr, size) }
                default { return(ptr, size) }
            }
         */
    }
}

