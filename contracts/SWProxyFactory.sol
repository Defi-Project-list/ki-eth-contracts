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

    event SWCreated(address indexed sw, bytes8 indexed version, address indexed owner);
    event SWUpgraded(address indexed sw, bytes8 indexed version);
    event SWFixed(address indexed sw, bytes8 indexed version, address indexed owner);
    event VersionAdded(bytes8 indexed version, address indexed code);

    constructor() public {
        swProxy = new SWProxy();
    }

    function _createSmartWallet(address _creator, address _target) private returns (address result) {
        bytes memory
        _code = hex"609c8061000d6000396000f300366018573415601657336000523460205260406000a05b005b6000805260046000601c376302d05d3f6000511415604d5773dadadadadadadadadadadadadadadadadadadada602052602080f35b366000803760008036600073bebebebebebebebebebebebebebebebebebebebe5af46000523d600060403e600051156097573415609257336000523460205260406000a05b3d6040f35b3d6040fd";
        bytes20 creatorBytes = bytes20(_creator);
        bytes20 targetBytes = bytes20(_target);
        for (uint i = 0; i < 20; i++) {
            _code[63 + i] = creatorBytes[i];
            _code[103 + i] = targetBytes[i];
        }
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            result := create(0, add(_code, 0x20), mload(_code))
        }
    }

    function upgrade(bytes8 _version) external {
        address _code = versions_code[_version];
        require(_code != address(0));
        address _owner = SWProxy(msg.sender).owner();
        SmartWallet storage _sw = accounts_smartwallet[_owner];
        require(msg.sender == _sw.addr && _sw.owner == true);
        smartwallets_version[_sw.addr] = _version;
        SWProxy(msg.sender).init(_owner, _code);
        emit SWUpgraded(_sw.addr, production_version);
    }

    function addVersion(bytes8 _version, address _target) public {
        require(_target != address(0));
        address _code = versions_code[_version];
        require(_code == address(0));
        versions_code[_version] = _target;
        production_version = _version;
        production_version_code = _target;
        emit VersionAdded(_version, _code);
    }

    function fixMySmartWallet() public {
        SmartWallet storage _sw = accounts_smartwallet[msg.sender];
        require(msg.sender == _sw.addr && _sw.owner == true);
        bytes8 _version = smartwallets_version[_sw.addr];
        address _code = versions_code[_version];
        require(_code != address(0));
        SWProxy(msg.sender).init(msg.sender, _code);
        emit SWFixed(_sw.addr, _version, msg.sender);
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
            smartwallets_version[_sw.addr] = production_version;
            SWProxy(_sw.addr).init(msg.sender, production_version_code);
            emit SWCreated(_sw.addr, production_version, msg.sender);
        }
        return _sw.addr;
    }
}

