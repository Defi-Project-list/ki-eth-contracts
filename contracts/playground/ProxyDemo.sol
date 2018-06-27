pragma solidity ^0.4.21;

contract Ownable {
  address public owner;

  function Ownable() public {
    owner = msg.sender;
  }

  modifier onlyOwner() {
    require(msg.sender == owner);

    _;
  }

  function transferOwnership(address newOwner) onlyOwner public {
    if (newOwner != address(0)) {
      owner = newOwner;
    }
  }

}

contract Store is Ownable {
    address internal target;
    mapping (address => bool) internal initialized;

    uint256 internal value;
}

contract Store2 is Store {
    uint256 value2;
}

contract Store3 is Store2 {
    uint256 value3;
}

contract Store4 is Store3 {
    uint256 value4;
}

contract Base is Store {

    function upgradeTo(address _target) public onlyOwner {
        assert(target != _target);
        target = _target;
    }

    function getValue() public view returns (uint256) {
        return value;
    }

    function setValueLocal(uint256 _value) public {
        value = _value;
    }

    function delegatecallSetValue(address _logic, uint256 _value) {
        _logic.delegatecall(bytes4(sha3("setValue(uint256)")), _value); // Base's storage is set, Del is not modified
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
}

contract Del is Store {

  function setValue(uint256 _value) {
    value = _value * 2;
  }
  function setTriValue(uint256 _value) {
    value = _value * 3;
  }
}

contract Del2 is Store2 {

  function setValue(uint256 _value) {
    value = _value * 2;
  }
  function setTriValue(uint256 _value) {
    value = _value * 4;
    value2 = _value * 6;
  }
  function getValue2() public view returns (uint256) {
      return value2;
  }
}

contract Del3 is Store3 {

  function setValue(uint256 _value) {
    value = _value * 2;
  }
  function setTriValue(uint256 _value) {
    value = _value * 5;
    value2 = 1;
    value3 = 6;
  }

  function getValue2() public view returns (uint256) {
      return value2;
  }

  function getValue3() public view returns (uint256) {
      return value3;
  }

}

contract Del4 is Store4 {

  function setValue(uint256 _value) {
    value = _value * 2;
  }
  function setTriValue(uint256 _value) {
    value = _value * 4;
    value2 = 3;
    value4 = 5;
  }

  function getValue2() public view returns (uint256) {
      return value2;
  }

  function getValue3() public view returns (uint256) {
      return value3;
  }

  function getValue4() public view returns (uint256) {
      return value4;
  }

}

contract Caller {
    function setValueLocal(uint256 _value);
    function setTriValue(uint256 _value);
    function setValue(uint256 _value);
}

contract Caller2 {
    function getValue2() public view returns (uint256);
    function setValueLocal(uint256 _value);
    function setTriValue(uint256 _value);
}

contract Caller3 is Caller2 {
    function getValue3() public view returns (uint256);
}

contract Caller4 is Caller3 {
    function getValue4() public view returns (uint256);
}
