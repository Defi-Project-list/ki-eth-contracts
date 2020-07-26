// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.6.11;

import "./FactoryStorage.sol";
import "./lib/IOracle.sol";

contract Factory is FactoryStorage {

    event WalletCreated(address indexed wallet, bytes8 indexed version, address indexed owner);
    event WalletUpgraded(address indexed wallet, bytes8 indexed version);
    event WalletConfigurationRestored(address indexed wallet, bytes8 indexed version, address indexed owner);
    event WalletOwnershipRestored(address indexed wallet, address indexed owner);
    event WalletVersionRestored(address indexed wallet, bytes8 indexed version, address indexed owner);
    event VersionAdded(bytes8 indexed version, address indexed code, address indexed oracle);
    event VersionDeployed(bytes8 indexed version, address indexed code, address indexed oracle);
    event GotEther(address indexed from, uint256 value);

    constructor (address owner1, address owner2, address owner3) FactoryStorage(owner1, owner2, owner3) public {
    }

    function _createWallet(address _creator, address _target) private returns (address result) {
        bytes memory
        _code = hex"60998061000d6000396000f30036601657341560145734602052336001602080a25b005b6000805260046000601c376302d05d3f6000511415604b5773dadadadadadadadadadadadadadadadadadadada602052602080f35b366000803760008036600073bebebebebebebebebebebebebebebebebebebebe5af415608f57341560855734602052600051336002602080a35b3d6000803e3d6000f35b3d6000803e3d6000fd"; //log3-event-ids-address-funcid-opt (-2,-2) (min: 22440)
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

    function transferWalletOwnership(address _newOwner) external {
        address _curOwner = IProxy(msg.sender).owner();
        Wallet storage _sw = accounts_wallet[_curOwner];
        require(msg.sender == _sw.addr, "from: no wallet");
        require(_sw.owner == true, "from: not wallet owner");
        Wallet storage _sw2 = accounts_wallet[_newOwner];
        require(msg.sender == _sw2.addr, "to: not same wallet as from");
        require(_sw2.owner == false, "to: wallet owner");
        _sw2.owner = true;
        _sw.owner = false;
        _sw.addr = address(0);
        IProxy(msg.sender).init(_newOwner, address(0));
    }

    function addWalletBackup(address _backup) external {
        Wallet storage _sw = accounts_wallet[_backup];
        require(_sw.addr == address(0), "backup has no wallet");
        require(_sw.owner == false, "backup is wallet owner"); //
        address _owner = IProxy(msg.sender).owner();
        Wallet storage _sw_owner = accounts_wallet[_owner];
        require(msg.sender == _sw_owner.addr, "not wallet");
        require(_sw_owner.owner == true, "no wallet owner");
        _sw.addr = msg.sender;
    }

    function removeWalletBackup(address _backup) external {
        require(_backup != address(0), "no backup");
        Wallet storage _sw = accounts_wallet[_backup];
        require(_sw.addr == msg.sender, "not wallet");
        require(_sw.owner == false, "wallet backup not exist");
        _sw.addr = address(0);
    }

    function upgradeWallet(bytes8 _version) external {
        address _code = versions_code[_version];
        require(_code != address(0), "no version code");
        address _owner = IProxy(msg.sender).owner();
        Wallet storage _sw = accounts_wallet[_owner];
        require(msg.sender == _sw.addr && _sw.owner == true, "sender is not wallet owner");
        wallets_version[_sw.addr] = _version;
        IProxy(msg.sender).init(_owner, _code);
        IStorage(msg.sender).migrate();
        emit WalletUpgraded(_sw.addr, _version);
    }

    function addVersion(address _target, address _oracle) multiSig2of3(0) public {
        require(_target != address(0), "no version");
        require(_oracle != address(0), "no oracle version");
        require(IOracle(_oracle).initialized() != false, "oracle not initialized");
        bytes8 _version = IStorage(_target).version();
        require(IOracle(_oracle).version() == _version, 'version mistmatch');
        address _code = versions_code[_version];
        require(_code == address(0), "version exists");
        require(versions_oracle[_version] == address(0), "oracle exists");
        versions_code[_version] = _target;
        versions_oracle[_version] = _oracle;
        emit VersionAdded(_version, _code, _oracle);
    }

    function deployVersion(bytes8 _version) multiSig2of3(0) public {
        address _code = versions_code[_version];
        require(_code != address(0), "version not exist");
        address _oracle = versions_oracle[_version];
        require(_oracle != address(0), "oracle not exist");
        production_version = _version;
        production_version_code = _code;
        production_version_oracle = _oracle;
        emit VersionDeployed(_version, _code, _oracle);
    }

    function restoreWalletConfiguration() public {
        Wallet storage _sw = accounts_wallet[msg.sender];
        require(_sw.addr != address(0), "no wallet");
        require(_sw.owner == true, "not wallet owner");
        bytes8 _version = wallets_version[_sw.addr];
        if (_version == LATEST) {
            _version = production_version;
        }
        address _code = versions_code[_version];
        require(_code != address(0), "version not exist");
        IProxy(_sw.addr).init(msg.sender, _code);
        emit WalletConfigurationRestored(_sw.addr, _version, msg.sender);
    }

    function restoreWalletOwnership() public {
        Wallet storage _sw = accounts_wallet[msg.sender];
        require(_sw.addr != address(0), "no wallet");
        require(_sw.owner == true, "not wallet owner");

        IProxy(_sw.addr).init(msg.sender, address(0));
        emit WalletOwnershipRestored(_sw.addr, msg.sender);
    }

    function restoreWalletVersion() public {
        Wallet storage _sw = accounts_wallet[msg.sender];
        require(_sw.addr != address(0), "no wallet");
        require(_sw.owner == true, "not wallet owner");

        bytes8 _version = wallets_version[_sw.addr];
        if (_version == LATEST) {
            _version = production_version;
        }
        address _code = versions_code[_version];
        require(_code != address(0), "no version");
        IProxy(_sw.addr).init(address(0), _code);
        emit WalletVersionRestored(_sw.addr, _version, msg.sender);
    }

    function getLatestVersion() public view returns (address) {
        return production_version_code;
    }

    function getWallet(address _account) public view returns (address) {
        return accounts_wallet[_account].addr;
    }

    function createWallet(bool _auto) public returns (address) {
        require(address(swProxy) != address(0), "no proxy");
        require(production_version_code != address(0), "no prod version"); //Must be here - ProxyLatest also needs it.
        Wallet storage _sw = accounts_wallet[msg.sender];
        if (_sw.addr == address(0)) {
            _sw.addr = _createWallet(address(this), address(swProxy));
            require(_sw.addr != address(0), "wallet not created");
            _sw.owner = true;
            if (_auto) {
                require(address(swProxyLatest) != address(0), "no auto version");
                require(versions_code[LATEST] == address(swProxyLatest), "incorrect auto version");
                wallets_version[_sw.addr] = LATEST;
                IProxy(_sw.addr).init(msg.sender, address(swProxyLatest));
                IStorage(_sw.addr).migrate();
                emit WalletCreated(_sw.addr, LATEST, msg.sender);
            } else {
                wallets_version[_sw.addr] = production_version;
                IProxy(_sw.addr).init(msg.sender, production_version_code);
                IStorage(_sw.addr).migrate();
                emit WalletCreated(_sw.addr, production_version, msg.sender);
            }

        }
        return _sw.addr;
    }

    function oracle() public view returns (address _oracle) {
        bytes8 _version = wallets_version[msg.sender];
        if (_version == LATEST) {
            _version = production_version;
        }
        _oracle = versions_oracle[_version];
    }

    /*
    receive () external payable {
      if (msg.value > 0) {
        emit GotEther(msg.sender, msg.value);
      }
    }
    */

    fallback () external payable {
      /*
        bytes8 _version = wallets_version[msg.sender];
        if (_version == LATEST) {
            _version = production_version;
        }
        address _oracle = versions_oracle[_version];
       */
        //require(_oracle != address(0), "no oracle code");
        /*
        // solium-disable-next-line security/no-inline-assembly
        assembly {
                calldatacopy(0x00, 0x00, calldatasize)
                //let res := call(gas, sload(oracle_slot), callvalue, 0x00, calldatasize, 0, 0)
                let res := staticcall(gas, sload(_oracle), 0x00, calldatasize, 0, 0)
                returndatacopy(0x00, 0x00, returndatasize)
                if res { return(0x00, returndatasize) }
                revert(0x00, returndatasize)
            }
            */
    }
}

