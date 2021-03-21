// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "./FactoryStorage.sol";
import "./Factory.sol";

contract FactoryProxy is FactoryStorage {

    bool public frozen;
    
    constructor(address owner1, address owner2, address owner3) FactoryStorage(owner1, owner2, owner3) {
        // proxy = address(this);
    }

    function setTarget(address _target) public multiSig2of3(0) {
        require(frozen != true, "frozen");
        require(_target != address(0), "no target");
        target = _target;
    }

    function freezeTarget() public multiSig2of3(0) {
        frozen = true;
    }

    fallback () external {
        // solium-disable-next-line security/no-inline-assembly
        assembly {
                calldatacopy(0x00, 0x00, calldatasize())
                let res := delegatecall(gas(), sload(target.slot), 0x00, calldatasize(), 0, 0)
                returndatacopy(0x00, 0x00, returndatasize())
                if res { return(0x00, returndatasize()) }
                revert(0x00, returndatasize())
            }
    }
}
