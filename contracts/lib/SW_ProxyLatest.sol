pragma solidity 0.4.24;

import "./SW_StorageBase.sol";

contract SW_ProxyLatest is SW_StorageBase {

    function () payable public {
        address latest = ICreator(this.creator()).getLatestVersion();
        // solium-disable-next-line security/no-inline-assembly
        assembly {
                calldatacopy(0x00, 0x00, calldatasize)
                let res := delegatecall(gas, latest, 0x00, calldatasize, 0, 0)
                returndatacopy(0x00, 0x00, returndatasize)
                if res { return(0x00, returndatasize) }
                revert(0x00, returndatasize)
            }
    }
}

