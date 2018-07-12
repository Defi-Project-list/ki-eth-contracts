pragma solidity 0.4.24;

import "./SW_FactoryStorage.sol";
import "./SW_Factory.sol";

contract SW_FactoryProxy is SW_FactoryStorage {

    constructor() SW_FactoryStorage() public {
    }

    function setTarget(address _target) onlyOwner() public {
        require(_target != address(0));
        target = _target;
        SW_Factory(this).init();
    }

    function () payable public {
        // solium-disable-next-line security/no-inline-assembly
        assembly {
                calldatacopy(0x00, 0x00, calldatasize)
                let res := delegatecall(gas, sload(target_slot), 0x00, calldatasize, 0, 0)
                returndatacopy(0x00, 0x00, returndatasize)
                if res { return(0x00, returndatasize) }
                revert(0x00, returndatasize)
            }
    }
}
