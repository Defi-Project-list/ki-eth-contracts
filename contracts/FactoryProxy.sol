// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.6.11;

import "./lib/FactoryClaimable.sol";
import "./Factory.sol";

contract FactoryProxy is FactoryClaimable {

    constructor() FactoryClaimable() public {
        proxy = address(this);
    }

    function setTarget(address _target) public onlyOwner() {
        require(_target != address(0), "no target");
        target = _target;
        FactoryStorage(this).migrate();
    }

    fallback () external payable {
        // solium-disable-next-line security/no-inline-assembly
        assembly {
                calldatacopy(0x00, 0x00, calldatasize())
                let res := delegatecall(gas(), sload(target_slot), 0x00, calldatasize(), 0, 0)
                returndatacopy(0x00, 0x00, returndatasize())
                if res { return(0x00, returndatasize()) }
                revert(0x00, returndatasize())
            }
    }
}
