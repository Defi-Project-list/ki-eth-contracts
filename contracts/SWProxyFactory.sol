pragma solidity 0.4.24;

import "./SWProxy.sol";

contract SWProxyFactory {
    SWProxy public swProxy;

    struct SmartWallet {
        address addr;
        bool owner;
    }
    mapping(address => SmartWallet) private accounts_smartwallet;
    mapping(address => bytes8) private smartwallets_version;
    mapping(bytes8 => address) private versions_code;

    bytes8 private production_version;
    address private production_version_code;

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

    function setTarget(bytes8 _id) external {
        address _code = versions_code[_id];
        require(_code != address(0));
        address _owner = SWProxy(msg.sender).owner();
        SmartWallet storage _sw = accounts_smartwallet[_owner];
        require(msg.sender == _sw.addr && _sw.owner == true);
        SWProxy(msg.sender).init(_owner, _code);
    }

    function addVersion(bytes8 _id, address _target) public {
        require(_target != address(0));
        address _code = versions_code[_id];
        require(_code == address(0));
        versions_code[_id] = _target;
        production_version = _id;
        production_version_code = _target;
    }

    function fixme() public {
        //address _sw = smartwallets[msg.sender];
        //require(_sw != address(0));
        //(SWProxy(_sw)).init(msg.sender, 0x0);
    }

    function getSmartWallet(address _account) public view returns (address) {
        return accounts_smartwallet[_account].addr;
    }

    function createSmartWallet() public returns (address) {
        require(production_version_code != address(0));
        SmartWallet storage _sw = accounts_smartwallet[msg.sender];
        if (_sw.addr == address(0)) {
            _sw.addr = _createSmartWallet(address(this), swProxy);
            require(_sw.addr != address(0));
            _sw.owner = true;
            (SWProxy(_sw.addr)).init(msg.sender, production_version_code);
            emit SWCreated(msg.sender, _sw.addr);
        }
        return _sw.addr;
    }
}

