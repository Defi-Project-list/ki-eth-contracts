pragma solidity ^0.4.24;

contract Name {
    address private target;
    uint8 public value;

    function setValue(uint8 _value) public {
        value = _value;
    }
}

contract NamePayable {
    address private target;
    uint8 public value;

    function setValue(uint8 _value) public payable {
        value = _value;
    }
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
contract NameProxy {
    address private target;

    function setTarget(address _target) public {
        target = _target;
    }

    function () payable public {
        bytes memory data = msg.data;
        address impl = target;

        if (data.length != 0x0) {

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
    bytes memory clone = hex"600034603b57603080600f833981f36000368180378080368173bebebebebebebebebebebebebebebebebebebebe5af43d82803e15602c573d90f35b3d90fd";
    bytes20 targetBytes = bytes20(target);
    for (uint i = 0; i < 20; i++) {
      clone[26 + i] = targetBytes[i];
    }
    assembly {
      let len := mload(clone)
      let data := add(clone, 0x20)
      result := create(0, data, len)
    }
  }
}

contract NameProxyFactory is CloneFactory {
    address public nameProxy;
    mapping(address => address) public clones;


    constructor() public {
        nameProxy = new NameProxy();
    }

    function clone(address _target) public {
        address _clone = clones[msg.sender];
        if (_clone == address(0)) {
            _clone = createClone(nameProxy);
            require(_clone != address(0));
            clones[msg.sender] = _clone;
            NameProxy(_clone).setTarget(_target);
        }
    }
}
