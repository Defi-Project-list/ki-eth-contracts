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

contract Storage1 is Storage0 {
    uint256 public value;
}

contract Version1 is Storage1 {
    function setValue(uint8 _value) public {
        value = _value;
    }
}

contract Version2_Payable is Storage1 {
    function setValue(uint8 _value) public payable {
        value = _value;
    }
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}

contract SWProxy is Storage0 {

    event GotEther   (address indexed from, uint256 value);

    function () payable public {
        bytes memory data = msg.data;

        if (data.length != 0x0) {
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
        }
        assembly {
                let value := callvalue
                if gt(value, 0) {
                        mstore(0x20, caller)
                        mstore(0x40, value)
                        log0(0x20, 0x40)
                }
        }

    }
}

contract SWProxyFactory {
    address public swProxy;
    mapping(address => address) public clones;

    event CloneCreated(address indexed target, address clone);

    constructor() public {
        swProxy = new SWProxy();
    }

    function createClone(address creator, address target) internal returns (address result) {
        bytes memory
        //clone = hex"600034603b57603080600f833981f36000368180378080368173bebebebebebebebebebebebebebebebebebebebe5af43d82803e15602c573d90f35b3d90fd";
        clone = hex"607180600c6000396000f3006000805260046000601c376302d05d3f600051141560355773dadadadadadadadadadadadadadadadadadadada60005260206000f35b366000803760008036600073bebebebebebebebebebebebebebebebebebebebe5af46000523d600060203e60005115606c573d6020f35b3d6020fd";
        bytes20 targetBytes = bytes20(target);
        bytes20 creatorBytes = bytes20(creator);
        for (uint i = 0; i < 20; i++) {
            //clone[26 + i] = targetBytes[i];
            clone[78 + i] = targetBytes[i];
            clone[37 + i] = creatorBytes[i];
        }
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            result := create(0, add(clone, 0x20), mload(clone))
        }
    }

    function fixme() public {
        address _clone = clones[msg.sender];
        if (_clone != address(0)) {
            (SWProxy(_clone)).init(msg.sender, 0x0);
        }
    }

    function clone(address _target) public {
        address _clone = clones[msg.sender];
        if (_clone == address(0)) {
            _clone = createClone(address(this), swProxy);
            require(_clone != address(0));
            clones[msg.sender] = _clone;
            (SWProxy(_clone)).init(msg.sender, _target);
        }
    }
}

contract Sender {
    function send(address _to, uint256 _value) public{
        _to.transfer(_value);
    }
    function () payable public {}
}
