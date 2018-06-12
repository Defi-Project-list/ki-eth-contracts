pragma solidity ^0.4.18;

contract Proxied {
  address public target;
  mapping (address => bool) public initialized;

  event EventUpgrade(address indexed newTarget, address indexed oldTarget, address indexed admin);
  event EventInitialized(address indexed target);

  function upgradeTo(address _target) public;
}

contract Upgradeable is Proxied {
    function Upgradeable() public {
        target = address(this);
    }
    function upgradeTo(address) public {
        assert(true); // this is used by isUpgradeable() in Proxy
    }
    modifier initializeOnceOnly() {
        if(!initialized[target]) {
            initialized[target] = true;
            EventInitialized(target);
            _;
        }
    }
    function initialize() initializeOnceOnly public {
        // initialize contract state variables here
    }
}

contract Proxy is Proxied {
    function Proxy(address _target) public {
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

        EventUpgrade(_target, oldTarget, msg.sender);
    }

    function () payable public {
        bytes memory data = msg.data;
        address impl = target;

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
        assembly { size := extcodesize(_target) }
        return size > 0;
    }

    function isUpgradeable(address _target) internal view returns (bool) {
        return Upgradeable(_target).call(bytes4(keccak256("upgradeTo(address)")), address(this));
    }
}



contract UintEther_Payable is Proxy {
    uint value;

    function getValue() view public returns (uint) {
        return value;
    }

    function setValue() payable public {
        value = msg.value;
    }
}

contract UintEther_Payable2 is Upgradeable {
    uint value;

    function getValue() view public returns (uint) {
        return value*2;
    }

    function setValue() payable public {
        value = msg.value;
    }
}

contract UintEther_Normal is Upgradeable {
    uint value;

    function getValue() view public returns (uint) {
        return value;
    }

    function setValue() payable public {
        value = 10;
    }
}

contract UintEther_Payable3 is Upgradeable {
    uint value;

    function getValue() view public returns (uint) {
        return value;
    }

    function setValue() payable public {
        value = msg.value;
    }
}

contract UintEther_NotPayable is Upgradeable {
    uint value;

    function getValue() view public returns (uint) {
        return value;
    }

    function setValue() public {
        value = msg.value;
    }
}


contract Test {
    uint256 value;

    constructor() public {
        value = 10;
    }

    function getValue() public view returns (uint256) {
        return this.balance + value;
    }

    function x() payable public {
        bytes memory data = msg.data;
        address impl = 0x692a70d2e424a56d2c6c27aa97d1a86395877b3a;

        assembly {
            let result := delegatecall(gas, impl, add(data, 0x20), mload(data), 0, 0)
            let size := returndatasize

            let ptr := mload(0x40)
            returndatacopy(ptr, 0, size)

            switch result
            case 0 { revert(ptr, size) }
            default { return(ptr, size) }
        }
        value=20;
    }
}


contract Test2 {
    uint256 value;

    function Test() public {
    }

    function getValue() public view returns (uint256) {
        return address(this).balance + value;
    }

    function x() payable public {
        value=30;
    }
}
