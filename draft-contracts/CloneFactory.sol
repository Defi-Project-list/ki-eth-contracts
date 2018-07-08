pragma solidity ^0.4.23;

contract Name {
    string public name;
    uint256 public value;

    function setName(string _name) public {
        name = _name;
    }

    function setValue(uint256 _value) public {
        value = _value;
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

contract NameFactory is CloneFactory {
    address public nameLib;

    constructor() public {
        nameLib = new Name();
    }

    function clone() public returns (address) {
        return createClone(nameLib);
    }
}
