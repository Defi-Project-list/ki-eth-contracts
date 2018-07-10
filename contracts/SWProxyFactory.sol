pragma solidity 0.4.24;

import "./SWProxy.sol";

contract SWProxyFactory {
    address public swProxy;
    address public lastver;
    mapping(address => address) private smartwallets;
    mapping(bytes8 => address) private versions;

    event SWCreated(address indexed target, address clone);

    constructor() public {
        swProxy = new SWProxy();
    }

    function _createSmartWallet(address _creator, address _target) private returns (address result) {
        bytes memory
        _sw = hex"609c8061000d6000396000f300366018573415601657336000523460205260406000a05b005b6000805260046000601c376302d05d3f6000511415604d5773dadadadadadadadadadadadadadadadadadadada602052602080f35b366000803760008036600073bebebebebebebebebebebebebebebebebebebebe5af46000523d600060403e600051156097573415609257336000523460205260406000a05b3d6040f35b3d6040fd";
        bytes20 creatorBytes = bytes20(_creator);
        bytes20 targetBytes = bytes20(_target);
        for (uint i = 0; i < 20; i++) {
            _sw[63 + i] = creatorBytes[i];
            _sw[103 + i] = targetBytes[i];
        }
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            result := create(0, add(_sw, 0x20), mload(_sw))
        }
    }

    function setTarget(bytes8 _id) public {
        require(versions[_id] != address(0));

    }

    function addVersion(bytes8 _id, address _target) public {
        require(_target != address(0));
        require(versions[_id] == address(0));
        versions[_id] = _target;
        lastver = _target;
    }

    function fixme() public {
        address _sw = smartwallets[msg.sender];
        require(_sw != address(0));
        (SWProxy(_sw)).init(msg.sender, 0x0);
    }

    function getSmartWallet(address _account) public view returns (address) {
        return smartwallets[_account];
    }

    function createSmartWallet() public returns (address) {
        require(lastver != address(0));
        address _sw = smartwallets[msg.sender];
        if (_sw == address(0)) {
            _sw = _createSmartWallet(address(this), swProxy);
            require(_sw != address(0));
            smartwallets[msg.sender] = _sw;
            (SWProxy(_sw)).init(msg.sender, lastver);
            emit SWCreated(msg.sender, _sw);
        }
        return _sw;
    }
}

