pragma solidity 0.4.24;

import "./SWProxy.sol";

contract SWProxyFactory {
    address public swProxy;
    mapping(address => address) public clones;

    event CloneCreated(address indexed target, address clone);

    constructor() public {
        swProxy = new SWProxy();
    }

    function createClone2(address _creator, address _target) internal returns (address result) {
        bytes memory
        //clone = hex"600034603b57603080600f833981f36000368180378080368173bebebebebebebebebebebebebebebebebebebebe5af43d82803e15602c573d90f35b3d90fd";
        //clone = hex"607180600c6000396000f3006000805260046000601c376302d05d3f600051141560355773dadadadadadadadadadadadadadadadadadadada60005260206000f35b366000803760008036600073bebebebebebebebebebebebebebebebebebebebe5af46000523d600060203e60005115606c573d6020f35b3d6020fd";
        clone = hex"607180600c6000396000f3006000805260046000601c376302d05d3f600051141560355773dadadadadadadadadadadadadadadadadadadada60005260206000f35b366000803760008036600073bebebebebebebebebebebebebebebebebebebebe5af46000523d600060203e60005115606c573d6020f35b3d6020fd";
        bytes20 creatorBytes = bytes20(_creator);
        bytes20 targetBytes = bytes20(_target);
        for (uint i = 0; i < 20; i++) {
            //clone[26 + i] = targetBytes[i];
            clone[37 + i] = creatorBytes[i];
            clone[78 + i] = targetBytes[i];
        }
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            result := create(0, add(clone, 0x20), mload(clone))
        }
    }

    //function createClone(address _creator, address _target, address _owner) internal returns (address result) {
    function createClone(address _creator, address _target) internal returns (address result) {
        bytes memory
        //clone = hex"73bebebebebebebebebebebebebebebebebebebebe60005573acacacacacacacacacacacacacacacacacacacac600155605e80603c6000396000f3006000805260046000601c376302d05d3f600051141560355773dadadadadadadadadadadadadadadadadadadada60005260206000f35b366000803760008036600080545af46000523d600060203e600051156059573d6020f35b3d6020fd";
        //clone = hex"73bebebebebebebebebebebebebebebebebebebebe60005573acacacacacacacacacacacacacacacacacacacac60015560968061003d6000396000f300366018573415601657336000523460205260206000a05b005b6000805260046000601c3773dadadadadadadadadadadadadadadadadadadada6020526302d05d3f6000511415604d57602080f35b366000803760008036600073bebebebebebebebebebebebebebebebebebebebe5af46000523d600060403e60005115609157336000523460205260206000a03d6040f35b3d6040fd";
        clone = hex"60968061000d6000396000f300366018573415601657336000523460205260406000a05b005b6000805260046000601c3773dadadadadadadadadadadadadadadadadadadada6020526302d05d3f6000511415604d57602080f35b366000803760008036600073bebebebebebebebebebebebebebebebebebebebe5af46000523d600060403e60005115609157336000523460205260406000a03d6040f35b3d6040fd";
        bytes20 creatorBytes = bytes20(_creator);
        bytes20 targetBytes = bytes20(_target);
        //bytes20 ownerBytes = bytes20(_owner);
        for (uint i = 0; i < 20; i++) {
            // clone[1 + i] = targetBytes[i];
            // clone[25 + i] = ownerBytes[i];
            // clone[98 + i] = creatorBytes[i];
            // clone[151 + i] = targetBytes[i];
            clone[50 + i] = creatorBytes[i];
            clone[103 + i] = targetBytes[i];
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
            //_clone = createClone2(address(this), swProxy);
            //_clone = createClone(address(this), _target, msg.sender);
            _clone = createClone(address(this), swProxy);
            require(_clone != address(0));
            clones[msg.sender] = _clone;
            //(SWProxy(_clone)).init(msg.sender, _target);
        }
    }
}

