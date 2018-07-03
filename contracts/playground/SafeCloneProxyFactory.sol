pragma solidity ^0.4.24;

contract Storage {
    bool public initialized;
    address public creator;
    address public target;
    address public owner;

    modifier onlyOnce () {
        require (initialized == false);
        initialized = true;
        _;
    }
    modifier onlyCreator () {
        require (msg.sender == creator);
        _;
    }
    modifier onlyOwner () {
        require (msg.sender == owner);
        _;
    }
}

contract Name is Storage {
    uint8 public value;

    function setValue(uint8 _value) public {
        value = _value;
    }
}

contract NamePayable is Storage {
    uint8 public value;

    function setValue(uint8 _value) public payable {
        value = _value;
    }
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}

contract SWProxy is Storage {

    function setTarget(address _target) onlyOwner() public {
        target = _target;
    }

    function init(address _owner, address _target) onlyOnce() public {
        creator = msg.sender;
        owner = _owner;
        target = _target;
    }

    function () payable public {
        bytes memory data = msg.data;
        address impl = target;

        if (data.length != 0x0) {
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
        }
    }
}

contract CloneFactory {

    event CloneCreated(address indexed target, address clone);

    function createClone(address target) public returns (address result) {
        bytes memory
        clone = hex"600034603b57603080600f833981f36000368180378080368173bebebebebebebebebebebebebebebebebebebebe5af43d82803e15602c573d90f35b3d90fd";
        bytes20 targetBytes = bytes20(target);
        for (uint i = 0; i < 20; i++) {
            clone[26 + i] = targetBytes[i];
        }
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            let len := mload(clone)
            let data := add(clone, 0x20)
            result := create(0, data, len)
        }
    }
}

contract SWProxyFactory is CloneFactory {
    address public swProxy;
    mapping(address => address) public clones;


    constructor() public {
        swProxy = new SWProxy();
    }

    function clone(address _target) public {
        address _clone = clones[msg.sender];
        if (_clone == address(0)) {
            _clone = createClone(swProxy);
            require(_clone != address(0));
            clones[msg.sender] = _clone;
            SWProxy(_clone).init(msg.sender, _target);
        }
    }
}
