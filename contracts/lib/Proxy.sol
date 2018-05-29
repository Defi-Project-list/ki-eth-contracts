pragma solidity 0.4.24;

import "./Proxied.sol";
import "./Upgradeable.sol";

contract Proxy is Proxied {

    constructor(address _target) public {
        upgradeTo(_target);
    }

    function upgradeTo(address _target) public {
        assert(target != _target);
        assert(isContract(_target));
        assert(isUpgradeable(_target));

        address oldTarget = target;
        target = _target;
        bytes4 initializeSignature = bytes4(keccak256("initialize()"));
        assert(target.delegatecall(initializeSignature));

        emit EventUpgrade(_target, oldTarget, msg.sender);
    }

    function () payable public {
        bytes memory data = msg.data;
        address impl = target;

        //solium-disable-next-line security/no-inline-assembly
        assembly {
            let result := delegatecall(gas, impl, add(data, 0x20), mload(data), 0, 0)
            let size := returndatasize

            let ptr := mload(0x40)
            returndatacopy(ptr, 0, size)

            switch result
            case 0 { revert(ptr, size) }
            default { return(ptr, size) }
        }
    }

    function isContract(address _target) internal view returns (bool) {
        uint256 size;
        //solium-disable-next-line security/no-inline-assembly
        assembly { size := extcodesize(_target) }
        return size > 0;
    }

    //function isUpgradeable(address _target) internal view returns (bool) {
    function isUpgradeable(address _target) internal returns (bool) {
        //return Upgradeable(_target).call(bytes4(keccak256("upgradeTo(address)")), address(this));
        return address(_target).call(bytes4(keccak256("upgradeTo(address)")), address(this));
    }
}
