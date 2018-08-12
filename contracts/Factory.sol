pragma solidity 0.4.24;

import "./FactoryStorage.sol";

contract Factory is FactoryStorage {

    event Created(address indexed sw, bytes8 indexed version, address indexed owner);
    event Upgraded(address indexed sw, bytes8 indexed version);
    event Fixed(address indexed sw, bytes8 indexed version, address indexed owner);
    event VersionAdded(bytes8 indexed version, address indexed code);
    event VersionDeployed(bytes8 indexed version, address indexed code);

    constructor() FactoryStorage() public {
    }

    function _createWallet(address _creator, address _target) private returns (address result) {
        bytes memory
        _code   = hex"60998061000d6000396000f30036601657341560145734602052336001602080a25b005b6000805260046000601c376302d05d3f6000511415604b5773dadadadadadadadadadadadadadadadadadadada602052602080f35b366000803760008036600073bebebebebebebebebebebebebebebebebebebebe5af415608f57341560855734602052600051336002602080a35b3d6000803e3d6000f35b3d6000803e3d6000fd"; //log3-event-ids-address-funcid-opt (-2,-2) (min: 22440)
        bytes20 creatorBytes = bytes20(_creator);
        bytes20 targetBytes = bytes20(_target);
        for (uint i = 0; i < 20; i++) {
            _code[61 + i] = creatorBytes[i];
            _code[101 + i] = targetBytes[i];
        }
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            result := create(0, add(_code, 0x20), mload(_code))
        }
    }

    function changeOwner(address _newOwner) external {
        address _curOwner = IProxy(msg.sender).owner();
        Wallet storage _sw = accounts_wallet[_curOwner];
        require(msg.sender == _sw.addr && _sw.owner == true);
        Wallet storage _sw2 = accounts_wallet[_newOwner];
        require(msg.sender == _sw2.addr && _sw2.owner == false);
        _sw2.owner = true;
        _sw.owner = false;
        _sw.addr = address(0);
        IProxy(msg.sender).init(_newOwner, address(0));
    }

    function addBackup(address _backup) external {
        Wallet storage _sw = accounts_wallet[_backup];
        require(_sw.addr == address(0) && _sw.owner == false);
        address _owner = IProxy(msg.sender).owner();
        Wallet storage _sw_owner = accounts_wallet[_owner];
        require(msg.sender == _sw_owner.addr && _sw_owner.owner == true);
        _sw.addr = msg.sender;  
    }

    function removeBackup(address _backup) external {
        Wallet storage _sw = accounts_wallet[_backup];
        require(_sw.addr != address(0));
        require(_sw.addr == msg.sender && _sw.owner == false);
        _sw.addr = address(0);
    }

    function upgrade(bytes8 _version) external {
        address _code = versions_code[_version];
        require(_code != address(0));
        address _owner = IProxy(msg.sender).owner();
        Wallet storage _sw = accounts_wallet[_owner];
        require(msg.sender == _sw.addr && _sw.owner == true);
        wallets_version[_sw.addr] = _version;
        IProxy(msg.sender).init(_owner, _code);
        IStorage(msg.sender).migrate();
        emit Upgraded(_sw.addr, _version);
    }

    function addVersion(address _target) onlyOwner() public {
        require(_target != address(0));
        address _owner = IStorageBase(_target).owner();
        require(msg.sender == _owner);
        bytes8 _version = IStorage(_target).version();
        address _code = versions_code[_version];
        require(_code == address(0));
        versions_code[_version] = _target;
        emit VersionAdded(_version, _code);
    }

    function deployVersion(bytes8 _version) onlyOwner() public {
        address _code = versions_code[_version];
        require(_code != address(0));
        production_version = _version;
        production_version_code = _code;
        emit VersionDeployed(_version, _code);
    }

    function fixWalletPermissions() public {
        Wallet storage _sw = accounts_wallet[msg.sender];
        require(_sw.addr != address(0) && _sw.owner == true);
        bytes8 _version = wallets_version[_sw.addr];
        if (_version == LATEST) {
            _version = production_version;
        }
        address _code = versions_code[_version];
        require(_code != address(0));
        IProxy(_sw.addr).init(msg.sender, _code);
        emit Fixed(_sw.addr, _version, msg.sender);
    }

    function createWallet(bool _auto) public returns (address) {
        require(swProxy != address(0));
        require(production_version_code != address(0)); //Must be here - ProxyLatest also needs it.
        Wallet storage _sw = accounts_wallet[msg.sender];
        if (_sw.addr == address(0)) {
            _sw.addr = _createWallet(address(this), address(swProxy));
            require(_sw.addr != address(0));
            _sw.owner = true;
            if (_auto) {
                require(swProxyLatest != address(0));
                require(versions_code[LATEST] == address(swProxyLatest));
                wallets_version[_sw.addr] = LATEST;
                IProxy(_sw.addr).init(msg.sender, address(swProxyLatest));
                IStorage(_sw.addr).migrate();
                emit Created(_sw.addr, LATEST, msg.sender);
            } else {
                wallets_version[_sw.addr] = production_version;
                IProxy(_sw.addr).init(msg.sender, production_version_code);
                IStorage(_sw.addr).migrate();
                emit Created(_sw.addr, production_version, msg.sender);
            }

        }
        return _sw.addr;
    }
}

