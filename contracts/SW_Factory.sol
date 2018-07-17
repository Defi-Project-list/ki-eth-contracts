pragma solidity 0.4.24;

import "./SW_FactoryStorage.sol";

contract SW_Factory is SW_FactoryStorage {

    event SW_Created(address indexed sw, bytes8 indexed version, address indexed owner);
    event SW_Upgraded(address indexed sw, bytes8 indexed version);
    event SW_Fixed(address indexed sw, bytes8 indexed version, address indexed owner);
    event VersionAdded(bytes8 indexed version, address indexed code);

    constructor() SW_FactoryStorage() public {
    }

    function _createSmartWallet(address _creator, address _target) private returns (address result) {
        bytes memory
        //_code = hex"609c8061000d6000396000f300366018573415601657336000523460205260406000a05b005b6000805260046000601c376302d05d3f6000511415604d5773dadadadadadadadadadadadadadadadadadadada602052602080f35b366000803760008036600073bebebebebebebebebebebebebebebebebebebebe5af46000523d600060403e600051156097573415609257336000523460205260406000a05b3d6040f35b3d6040fd"; //log0 (min: 21949 gas)
        //_code = hex"60a08061000d6000396000f30036601a5734156018573360005234602052600160406000a15b005b6000805260046000601c376302d05d3f6000511415604f5773dadadadadadadadadadadadadadadadadadadada602052602080f35b366000803760008036600073bebebebebebebebebebebebebebebebebebebebe5af46000523d600060403e60005115609b5734156096573360005234602052600260406000a15b3d6040f35b3d6040fd"; //log1-event-ids (+1) (min: 22300)
        //_code = hex"609a8061000d6000396000f3003660175734156015573460005233600160206000a25b005b6000805260046000601c376302d05d3f6000511415604c5773dadadadadadadadadadadadadadadadadadadada602052602080f35b366000803760008036600073bebebebebebebebebebebebebebebebebebebebe5af46000523d600060403e6000511560955734156090573460005233600160206000a25b3d6040f35b3d6040fd"; //log2-event-ids-indexed-address (-1) (min: 22437)
        //_code = hex"60968061000d6000396000f30036601657341560145734602052336001602080a25b005b6000805260046000601c376302d05d3f6000511415604b5773dadadadadadadadadadadadadadadadadadadada602052602080f35b366000803760008036600073bebebebebebebebebebebebebebebebebebebebe5af415608c57341560825734602052336002602080a25b3d6000803e3d6000f35b3d6000803e3d6000fd"; //log2-event-ids-indexed-address-opt (-2) (min: 22440)
        //_code = hex"60998061000d6000396000f30036601657341560145734602052336001602080a25b005b6000805260046000601c376302d05d3f6000511415604b5773dadadadadadadadadadadadadadadadadadadada602052602080f35b366000803760008036600073bebebebebebebebebebebebebebebebebebebebe5af415608f57341560855734602052600051336002602080a35b3d6000803e3d6000f35b3d6000803e3d6000fd"; //log3-event-ids-address-funcid-opt (-2) (min: 22440)
        //_code   = hex"609a8061000d6000396000f30036601657341560145734602052336001602080a25b005b6000805260046000601c376302d05d3f6000511415604b5773dadadadadadadadadadadadadadadadadadadada602052602080f35b36600060203760008036602073bebebebebebebebebebebebebebebebebebebebe5af415609057341560865734602052600051336002602080a35b3d6000803e3d6000f35b3d6000803e3d6000fd"; //log3-event-ids-address-funcid-opt (-2,-1) (min: 22440)
        _code   = hex"60998061000d6000396000f30036601657341560145734602052336001602080a25b005b6000805260046000601c376302d05d3f6000511415604b5773dadadadadadadadadadadadadadadadadadadada602052602080f35b366000803760008036600073bebebebebebebebebebebebebebebebebebebebe5af415608f57341560855734602052600051336002602080a35b3d6000803e3d6000f35b3d6000803e3d6000fd"; //log3-event-ids-address-funcid-opt (-2,-2) (min: 22440)
        //_code =   hex"609b8061000d6000396000f3003660175734156015573460005233600160206000a25b005b6000805260046000601c376302d05d3f6000511415604d5773dadadadadadadadadadadadadadadadadadadada60005260206000f35b366000803760008036600073bebebebebebebebebebebebebebebebebebebebe5af46000523d600060203e6000511560965734156091573460005233600260206000a25b3d6020f35b3d6020fd"; //log2-event-ids-indexed-address-0x00 (-1, 0) (min: 22437)
        //_code = hex"60968061000d6000396000f300366015573415601357346000523360206000a15b005b6000805260046000601c376302d05d3f6000511415604a5773dadadadadadadadadadadadadadadadadadadada602052602080f35b366000803760008036600073bebebebebebebebebebebebebebebebebebebebe5af46000523d600060403e600051156091573415608c57346000523360206000a15b3d6040f35b3d6040fd"; //log1 (-3) (min: 22059 gas)
        //_code = hex"607680600c6000396000f30036600557005b6000805260046000601c376302d05d3f6000511415603a5773dadadadadadadadadadadadadadadadadadadada602052602080f35b366000803760008036600073bebebebebebebebebebebebebebebebebebebebe5af46000523d600060403e600051156071573d6040f35b3d6040fd"; //nolog (-20) (min: 21015 gas)
        bytes20 creatorBytes = bytes20(_creator);
        bytes20 targetBytes = bytes20(_target);
        for (uint i = 0; i < 20; i++) {
            _code[63 + i - 2] = creatorBytes[i];
            _code[103 + i - 2] = targetBytes[i];
        }
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            result := create(0, add(_code, 0x20), mload(_code))
        }
    }

    function changeOwner(address _newOwner) external {
        address _curOwner = IProxy(msg.sender).owner();
        SmartWallet storage _sw = accounts_smartwallet[_curOwner];
        require(msg.sender == _sw.addr && _sw.owner == true);
        SmartWallet storage _sw2 = accounts_smartwallet[_newOwner];
        require(msg.sender == _sw2.addr && _sw2.owner == false);
        bytes8 _version = smartwallets_version[msg.sender];
        address _code = versions_code[_version];
        require(_code != address(0));
        _sw.owner = false;
        _sw2.owner = true;
        IProxy(msg.sender).init(_newOwner, _code);
    }

    function addBackup(address _backup) external {
        SmartWallet storage _sw = accounts_smartwallet[_backup];
        require(_sw.addr == address(0) && _sw.owner == false);
        address _owner = IProxy(msg.sender).owner();
        SmartWallet storage _sw_owner = accounts_smartwallet[_owner];
        require(msg.sender == _sw_owner.addr && _sw_owner.owner == true);
        _sw.addr = msg.sender;
    }

    function removeBackup(address _backup) external {
        SmartWallet storage _sw = accounts_smartwallet[_backup];
        require(_sw.addr != address(0));
        require(_sw.addr == msg.sender && _sw.owner == false);
        _sw.addr = address(0);
    }


    function upgrade(bytes8 _version) external {
        address _code = versions_code[_version];
        require(_code != address(0));
        address _owner = IProxy(msg.sender).owner();
        SmartWallet storage _sw = accounts_smartwallet[_owner];
        require(msg.sender == _sw.addr && _sw.owner == true);
        smartwallets_version[_sw.addr] = _version;
        IProxy(msg.sender).init(_owner, _code);
        IStorage(msg.sender).migrate();
        emit SW_Upgraded(_sw.addr, _version);
    }

    function addVersion(address _target) onlyOwner() public {
        require(_target != address(0));
        bytes8 _version = IStorage(_target).version();
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
        IProxy(msg.sender).init(msg.sender, _code);
        emit SW_Fixed(_sw.addr, _version, msg.sender);
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
                IProxy(_sw.addr).init(msg.sender, address(swProxyLatest));
                IStorage(_sw.addr).migrate();
                emit SW_Created(_sw.addr, LATEST, msg.sender);
            } else {
                smartwallets_version[_sw.addr] = production_version;
                IProxy(_sw.addr).init(msg.sender, production_version_code);
                IStorage(_sw.addr).migrate();
                emit SW_Created(_sw.addr, production_version, msg.sender);
            }

        }
        return _sw.addr;
    }
}

