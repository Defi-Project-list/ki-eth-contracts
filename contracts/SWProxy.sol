pragma solidity ^0.4.24;

contract Storage0 {
    address public target;
    address public owner;

    function creator() view external returns (address) {
        return owner;
    }

    modifier onlyCreator () {
        require (msg.sender == this.creator());
        _;
    }

    modifier onlyOwner () {
        require (msg.sender == owner);
        _;
    }

    function init(address _owner, address _target) onlyCreator() public {
        owner = _owner;
        target = _target;
    }

    function setTarget(address _target) onlyOwner() public {
        target = _target;
    }

}

contract SWProxy is Storage0 {

    function () payable public {
        bytes memory data = msg.data;

        /*
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            let value := callvalue
            if gt(value, 0) {
                mstore(0x20, caller)
                mstore(0x40, value)
                log0(0x20, 0x40)
            }
        }
        */
        //if (data.length != 0x0) {
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
        //}
    }
}

