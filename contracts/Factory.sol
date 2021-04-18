// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v2;

import "./FactoryStorage.sol";
import "./lib/IOracle.sol";

contract Factory is FactoryStorage {
    event WalletCreated(
        address indexed wallet,
        bytes8 indexed version,
        address indexed owner
    );
    event WalletUpgraded(address indexed wallet, bytes8 indexed version);
    event WalletConfigurationRestored(
        address indexed wallet,
        bytes8 indexed version,
        address indexed owner
    );
    event WalletOwnershipRestored(
        address indexed wallet,
        address indexed owner
    );
    event WalletVersionRestored(
        address indexed wallet,
        bytes8 indexed version,
        address indexed owner
    );
    event VersionAdded(
        bytes8 indexed version,
        address indexed code,
        address indexed oracle
    );
    event VersionDeployed(
        bytes8 indexed version,
        address indexed code,
        address indexed oracle
    );

    constructor(
        address owner1,
        address owner2,
        address owner3
    ) FactoryStorage(owner1, owner2, owner3) {}

    function _createWallet(address _creator, address _target)
        private
        returns (address result)
    {
        bytes memory _code =
            hex"60998061000d6000396000f30036601657341560145734602052336001602080a25b005b6000805260046000601c376302d05d3f6000511415604b5773dadadadadadadadadadadadadadadadadadadada602052602080f35b366000803760008036600073bebebebebebebebebebebebebebebebebebebebe5af415608f57341560855734602052600051336002602080a35b3d6000803e3d6000f35b3d6000803e3d6000fd"; //log3-event-ids-address-funcid-opt (-2,-2) (min: 22440)
        bytes20 creatorBytes = bytes20(_creator);
        bytes20 targetBytes = bytes20(_target);
        for (uint256 i = 0; i < 20; i++) {
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
        require(
            msg.sender == _sw.addr && _sw.owner == true,
            "sender is not wallet owner"
        );
        wallets_version[_sw.addr] = _version;
        IProxy(msg.sender).init(_owner, _code);
        IStorage(msg.sender).migrate();
        emit WalletUpgraded(_sw.addr, _version);
    }

    function addVersion(address _target, address _oracle)
        public
        multiSig2of3(0)
    {
        require(_target != address(0), "no version");
        require(_oracle != address(0), "no oracle version");
        require(
            IOracle(_oracle).initialized() != false,
            "oracle not initialized"
        );
        bytes8 _version = IStorage(_target).version();
        require(IOracle(_oracle).version() == _version, "version mistmatch");
        address _code = versions_code[_version];
        require(_code == address(0), "version exists");
        require(versions_oracle[_version] == address(0), "oracle exists");
        versions_code[_version] = _target;
        versions_oracle[_version] = _oracle;
        emit VersionAdded(_version, _code, _oracle);
    }

    function deployVersion(bytes8 _version) public multiSig2of3(0) {
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
                require(
                    address(swProxyLatest) != address(0),
                    "no auto version"
                );
                require(
                    versions_code[LATEST] == address(swProxyLatest),
                    "incorrect auto version"
                );
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

    // keccak256("acceptTokens(address recipient,uint256 value,bytes32 secretHash)");
    bytes32 public constant TRANSFER_TYPEHASH = 0xf728cfc064674dacd2ced2a03acd588dfd299d5e4716726c6d5ec364d16406eb;
    // keccak256("acceptTokens(address recipient,uint256 value,bytes32 secretHash)");
    bytes32 public constant DOMAIN_SEPARATOR = 0xf728cfc064674dacd2ced2a03acd588dfd299d5e4716726c6d5ec364d16406eb;

    // bytes4(keccak256("sendEther(address payable,uint256)"));
    bytes4 public constant TRANSFER_SELECTOR = 0xc61f08fd;

    struct Transfer {
        uint8 v;
        bytes32 r;
        bytes32 s;
        address token;
        address to;
        uint256 value;
        uint256 sessionId;
        uint256 gasPriceLimit;
        uint256 eip712;
    }

    struct STransfer {
        uint8 v;
        bytes32 r;
        bytes32 s;
        address to;
        uint256 value;
        uint256 sessionId;
        uint256 gasPriceLimit;
    }

    function batchEthTransfer(STransfer[] calldata tr, uint128 nonceGroup, bool eip712) public {
        // address refund = _activator;
        unchecked {
        require(msg.sender == _activator, "Wallet: sender not allowed");
        uint256 nonce = s_nonce_group[nonceGroup] + (uint256(nonceGroup) << 128);
        uint256 minNonce = type(uint256).max;
        uint256 maxNonce = 0;
        uint256 minGasPrice = type(uint256).max;
        for(uint256 i = 0; i < tr.length; i++) {
            STransfer calldata call = tr[i];
            uint256 sessionId = call.sessionId;
            uint256 gasPriceLimit = call.gasPriceLimit;
            address to = call.to;
            uint256 value = call.value;
            address signer = ecrecover(
                _messageToRecover(keccak256(abi.encode(TRANSFER_TYPEHASH, to, value, sessionId, gasPriceLimit)), eip712),
                call.v,
                call.r,
                call.s
            );
            if (maxNonce < sessionId) {
                maxNonce = sessionId;
            }
            if (minNonce > sessionId) {
                minNonce = sessionId;
            }
            if (minGasPrice > gasPriceLimit) {
                minGasPrice = gasPriceLimit;
            }
            address wallet = accounts_wallet[signer].addr;
            require(wallet != address(0), "Factory: signer is not owner");
            (bool success, bytes memory res) =
                wallet.call(abi.encodeWithSignature("transferEth(address,uint256)", to, value));
            if (!success) {
                revert(_getRevertMsg(res));
            }
        }
        require(minGasPrice >= tx.gasprice, "Factory: gas price too high");
        require(minNonce >= nonce, "Factory: nonce too low");
        require(maxNonce < nonce + 100000, "Factory: nonce too high");
        s_nonce_group[nonceGroup] = (maxNonce >> 128) + 1;
      }
    }


    function batchTransfer(Transfer[] calldata tr, uint128 nonceGroup) public {
      // address refund = _activator;
      unchecked {
        require(msg.sender == _activator, "Wallet: sender not allowed");
        uint256 nonce = s_nonce_group[nonceGroup] + (uint256(nonceGroup) << 128);
        uint256 minNonce = type(uint256).max;
        uint256 maxNonce = 0;
        uint256 minGasPrice = type(uint256).max;
        for(uint256 i = 0; i < tr.length; i++) {
            Transfer calldata call = tr[i];
            uint256 sessionId = call.sessionId;
            uint256 gasPriceLimit = call.gasPriceLimit;
            address to = call.to;
            uint256 value = call.value;
            address token = call.token;
            address signer = ecrecover(
                _messageToRecover(
                    keccak256(abi.encode(TRANSFER_TYPEHASH, token, to, value, sessionId, gasPriceLimit)),
                    call.eip712 > 0
                ),
                call.v,
                call.r,
                call.s
            );
            if (maxNonce < sessionId) {
                maxNonce = sessionId;
            }
            if (minNonce > sessionId) {
                minNonce = sessionId;
            }
            if (minGasPrice > gasPriceLimit) {
                minGasPrice = gasPriceLimit;
            }
            address wallet = accounts_wallet[signer].addr;
            require(wallet != address(0), "Factory: signer is not owner");
            (bool success, bytes memory res) = token == address(0) ?
                // wallet.call(abi.encodeWithSelector(0xe9bb84c2, to,value)):
                // wallet.call(abi.encodeWithSelector(0x9db5dbe4, token, to, value));
                // e9bb84c27dc2c8bc5107c5b354d1ce66def1bcb8670a1a1bc2f2c410225e3050
                wallet.call(abi.encodeWithSignature("transferEth(address,uint256)", to, value)):
                // 9db5dbe4982ea7264288816937f1d1290e660d28eca5904e32464a2f1578e4f3
                wallet.call(abi.encodeWithSignature("transferERC20(address,address,uint256)", token, to, value));
            if (!success) {
                revert(_getRevertMsg(res));
            }
        }
        require(minGasPrice >= tx.gasprice, "Factory: gas price too high");
        require(minNonce >= nonce, "Factory: nonce too low");
        require(maxNonce < nonce + 100000, "Factory: nonce too high");
        s_nonce_group[nonceGroup] = (maxNonce >> 128) + 1;
      }
    }

    function _getRevertMsg(bytes memory returnData)
        internal
        pure
        returns (string memory)
    {
        if (returnData.length < 68)
            return "Wallet: Transaction reverted silently";

        assembly {
            returnData := add(returnData, 0x04)
        }
        return abi.decode(returnData, (string));
    }


    function _messageToRecover(bytes32 hashedUnsignedMessage, bool eip712)
        private
        pure
        returns (bytes32)
    {
        if (eip712) {
            return
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR,
                        hashedUnsignedMessage
                    )
                );
        }
        return
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    hashedUnsignedMessage
                )
            );
    }


    function operator() public view returns (address) {
      return _operator;
    }

    function activator() public view returns (address) {
      return _activator;
    }

    function managers() public view returns (address, address) {
      return (_operator, _activator);
    }

    function setOperator(address oper) public  multiSig2of3(0) {
      _operator = oper;
    }

    function setActivator(address act) public  multiSig2of3(0) {
      _activator = act;
    }

    /*
    receive () external payable {
      if (msg.value > 0) {
        emit GotEther(msg.sender, msg.value);
      }
    }
    */

    fallback() external {
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
