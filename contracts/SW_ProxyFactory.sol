pragma solidity 0.4.24;

import "./lib/SW_Proxy.sol";
import "./lib/SW_ProxyLatest.sol";

contract SW_ProxyFactory {
    SW_Proxy public swProxy;
    SW_ProxyLatest public swProxyLatest;

    bytes8 public constant LATEST = bytes8("latest");

    struct SmartWallet {
        address addr;
        bool owner;
    }
    mapping(address => SmartWallet) private accounts_smartwallet;
    mapping(address => bytes8) private smartwallets_version;
    mapping(bytes8 => address) private versions_code;

    bytes8 private production_version;
    address private production_version_code;

    event SW_Created(address indexed sw, bytes8 indexed version, address indexed owner);
    event SW_Upgraded(address indexed sw, bytes8 indexed version);
    event SW_Fixed(address indexed sw, bytes8 indexed version, address indexed owner);
    event VersionAdded(bytes8 indexed version, address indexed code);

    constructor() public {
        swProxy = new SW_Proxy();
        swProxyLatest = new SW_ProxyLatest();
        versions_code[LATEST] = swProxyLatest;
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

    function changeOwner(address _newOwner) external {
        address _curOwner = SW_Proxy(msg.sender).owner();
        SmartWallet storage _sw = accounts_smartwallet[_curOwner];
        require(msg.sender == _sw.addr && _sw.owner == true);
        SmartWallet storage _sw2 = accounts_smartwallet[_newOwner];
        require(msg.sender == _sw2.addr && _sw2.owner == false);
        bytes8 _version = smartwallets_version[msg.sender];
        address _code = versions_code[_version];
        require(_code != address(0));
        _sw.owner = false;
        _sw2.owner = true;
        SW_Proxy(msg.sender).init(_newOwner, _code);
    }

    function addBackup(address _backup) external {
        SmartWallet storage _sw = accounts_smartwallet[_backup];
        require(_sw.addr == address(0) && _sw.owner == false);
        address _owner = SW_Proxy(msg.sender).owner();
        SmartWallet storage _sw_owner = accounts_smartwallet[_owner];
        require(msg.sender == _sw_owner.addr && _sw_owner.owner == true);
        _sw.addr = msg.sender;
    }

    function removeBackup(address _backup) external {
        SmartWallet storage _sw = accounts_smartwallet[_backup];
        require(_sw.addr == msg.sender && _sw.owner == false);
        _sw.addr = address(0);
    }

    function getLatestVersion() external view returns (address) {
        return production_version_code;
    }

    function upgrade(bytes8 _version) external {
        address _code = versions_code[_version];
        require(_code != address(0));
        address _owner = SW_Proxy(msg.sender).owner();
        SmartWallet storage _sw = accounts_smartwallet[_owner];
        require(msg.sender == _sw.addr && _sw.owner == true);
        smartwallets_version[_sw.addr] = _version;
        SW_Proxy(msg.sender).init(_owner, _code);
        emit SW_Upgraded(_sw.addr, _version);
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
        SW_Proxy(msg.sender).init(msg.sender, _code);
        emit SW_Fixed(_sw.addr, _version, msg.sender);
    }

    function getSmartWallet(address _account) public view returns (address) {
        return accounts_smartwallet[_account].addr;
    }

    function createSmartWallet(bool _auto) public returns (address) {
        require(production_version_code != address(0));
        SmartWallet storage _sw = accounts_smartwallet[msg.sender];
        if (_sw.addr == address(0)) {
            _sw.addr = _createSmartWallet(address(this), address(swProxy));
            require(_sw.addr != address(0));
            _sw.owner = true;
            if (_auto) {
                smartwallets_version[_sw.addr] = LATEST;
                SW_Proxy(_sw.addr).init(msg.sender, address(swProxyLatest));
                emit SW_Created(_sw.addr, LATEST, msg.sender);
            } else {
                smartwallets_version[_sw.addr] = production_version;
                SW_Proxy(_sw.addr).init(msg.sender, production_version_code);
                emit SW_Created(_sw.addr, production_version, msg.sender);
            }

        }
        return _sw.addr;
    }
}

