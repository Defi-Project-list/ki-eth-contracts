pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/ownership/Claimable.sol";

import "./FactoryStorage.sol";
import "./Factory.sol";

contract FactoryProxy is Claimable, FactoryStorage {

    constructor() Claimable() FactoryStorage() public {
        proxy = address(this);
    }

    function setTarget(address _target) onlyOwner() public {
        require(_target != address(0));
        target = _target;
        FactoryStorage(this).migrate();
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
