// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v2;

import "./FactoryStorage.sol";
import "./lib/IOracle.sol";

struct Signature {
    uint8 v;
    bytes32 r;
    bytes32 s;
}

struct Call {
    bytes32 r;
    bytes32 s;
    address to;
    uint256 value;
    uint256 sessionId;
    address signer;
    bytes data;
}

struct MCall {
    uint256 value;
    address to;
    uint32 gasLimit;
    uint16 flags;
    bytes data;
}

struct MCalls {
    bytes32 r;
    bytes32 s;
    uint256 sessionId;
    address signer;
    uint8 v;
    MCall[] mcall;
}

struct MSCall {
    uint256 value;
    address signer;
    uint32 gasLimit;
    uint16 flags;
    address to;
    bytes data;
}

struct MSCalls {
    uint256 sessionId;
    MSCall[] mcall;
    Signature[] signatures;
}

/** @title Factory contract 
    @author Tal Asa <tal@kirobo.io> 
    @notice Factory contract - defines functions that are used by all related contracts
 */
contract Factory is FactoryStorage {
    bytes32 public constant BATCH_CALL_PACKED_TYPEHASH =
        keccak256(
            "BatchCallPacked(address to,uint256 value,uint256 sessionId,bytes data)"
        );

    bytes32 public constant BATCH_MULTI_CALL_TYPEHASH =
        keccak256(
            "BatchMultiCallPacked(address to,uint256 value,uint256 sessionId,bytes data)"
        );

    bytes32 public constant BATCH_MULTI_SIG_CALL_TYPEHASH =
        keccak256(
            "BatchMultiSigCall(Limits limits,Transaction transaction)Limits(uint256 sessionId)Transaction(address signer,address to,uint256 value,uint32 gasLimit,uint16 flags,bytes data)"
        );

    bytes32 public constant BATCH_MULTI_SIG_CALL_LIMITS_TYPEHASH =
        keccak256("Limits(uint256 sessionId)");

    bytes32 public constant BATCH_MULTI_SIG_CALL_TRANSACTION_TYPEHASH =
        keccak256(
            "Transaction(address signer,address to,uint256 value,uint32 gasLimit,uint16 flags,bytes data)"
        );

    event WalletCreated(
        address indexed wallet,
        bytes8 indexed version,
        address indexed owner
    );

    event WalletUpgraded(address indexed wallet, bytes8 indexed version);

    event WalletUpgradeRequested(
        address indexed wallet,
        bytes8 indexed version
    );

    event WalletUpgradeDismissed(
        address indexed wallet,
        bytes8 indexed version
    );

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

    event WalletOwnershipTransfered(
        address indexed wallet,
        address indexed owner,
        address indexed newOwner
    );

    event WalletBakcupCreated(
        address indexed wallet,
        address indexed owner,
        address indexed backup
    );

    event WalletBackupRemoved(address indexed wallet, address indexed backup);

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

    event BatchCallPackedReverted(
        address indexed wallet,
        uint256 nonce,
        uint256 index
    );
    event BatchMultiCallPackedFailed(
        address indexed wallet,
        uint256 nonce,
        uint256 index,
        uint256 innerIndex
    );
    event BatchMultiSigCallPackedFailed(
        address indexed wallet,
        uint256 nonce,
        uint256 index,
        uint256 innerIndex
    );
    event BatchTransfered(uint256 indexed mode, uint256 block, uint256 nonce);

    constructor(
        address owner1,
        address owner2,
        address owner3
    ) FactoryStorage(owner1, owner2, owner3) {}

    // receive() external payable {
    //     require(false, "Factory: not aceepting ether");
    // }

    function setActivator(address newActivator) external multiSig2of3(0) {
        s_activator = newActivator;
    }

    /** @notice transferWalletOwnership - the function transfers the ownership of the wallet 
                to the newOwner in the input param
        @param newOwner (address) - address of the new owner that the ownership will move to
     */
    function transferWalletOwnership(address newOwner) external {
        address curOwner = IProxy(msg.sender).owner();
        Wallet storage sp_sw = s_accounts_wallet[curOwner];
        require(msg.sender == sp_sw.addr, "from: no wallet");
        require(sp_sw.owner == true, "from: not wallet owner");
        Wallet storage sp_sw2 = s_accounts_wallet[newOwner];
        require(msg.sender == sp_sw2.addr, "to: not same wallet as from");
        require(sp_sw2.owner == false, "to: wallet owner");
        sp_sw2.owner = true;
        sp_sw.owner = false;
        sp_sw.addr = address(0);
        IProxy(msg.sender).init(newOwner, address(0));
        emit WalletOwnershipTransfered(sp_sw.addr, curOwner, newOwner);
    }

    /** @notice addWalletBackup - adds a backup to the current wallet owner 
        @param backup (address) - the address of the backup wallet
     */
    function addWalletBackup(address backup) external {
        Wallet storage sp_sw = s_accounts_wallet[backup];
        require(sp_sw.addr == address(0), "backup has no wallet");
        require(sp_sw.owner == false, "backup is wallet owner"); //
        address owner = IProxy(msg.sender).owner();
        Wallet storage sp_sw_owner = s_accounts_wallet[owner];
        require(msg.sender == sp_sw_owner.addr, "not wallet");
        require(sp_sw_owner.owner == true, "no wallet owner");
        sp_sw.addr = msg.sender;
        emit WalletBakcupCreated(sp_sw.addr, owner, backup);
    }

    /** @notice removeWalletBackup - removes a specific address from being the owners backup
        @param backup (address) - the address of the backup wallet
     */
    function removeWalletBackup(address backup) external {
        require(backup != address(0), "no backup");
        Wallet storage sp_sw = s_accounts_wallet[backup];
        require(sp_sw.addr == msg.sender, "not wallet");
        require(sp_sw.owner == false, "wallet backup not exist");
        sp_sw.addr = address(0);
        emit WalletBackupRemoved(sp_sw.addr, backup);
    }

    /** @notice upgradeWalletRequest - lets the owner of the wallet an option to upgrade his wallet version
        @param version (bytes8) - version number
    */
    function upgradeWalletRequest(bytes8 version) external {
        address code = s_versions_code[version];
        require(code != address(0), "no version code");
        address owner = IProxy(msg.sender).owner();
        Wallet storage sp_sw = s_accounts_wallet[owner];
        require(
            msg.sender == sp_sw.addr && sp_sw.owner == true,
            "sender is not wallet owner"
        );
        s_wallets_upgrade_requests[sp_sw.addr] = UpgradeRequest({
            version: version,
            validAt: block.timestamp + 48 hours
        });
        emit WalletUpgradeRequested(sp_sw.addr, version);
    }

    function upgradeWalletDismiss() external {
        address owner = IProxy(msg.sender).owner();
        Wallet storage sp_sw = s_accounts_wallet[owner];
        require(
            msg.sender == sp_sw.addr && sp_sw.owner == true,
            "sender is not wallet owner"
        );
        UpgradeRequest storage sp_upgradeRequest = s_wallets_upgrade_requests[
            sp_sw.addr
        ];
        require(sp_upgradeRequest.validAt > 0, "request not exsist");
        sp_upgradeRequest.validAt = 0;
        emit WalletUpgradeDismissed(sp_sw.addr, sp_upgradeRequest.version);
    }

    function upgradeWalletExecute() external {
        address owner = IProxy(msg.sender).owner();
        Wallet storage sp_sw = s_accounts_wallet[owner];
        require(
            msg.sender == sp_sw.addr && sp_sw.owner == true,
            "sender is not wallet owner"
        );
        UpgradeRequest storage sp_upgradeRequest = s_wallets_upgrade_requests[
            sp_sw.addr
        ];
        require(sp_upgradeRequest.validAt > 0, "request not exsist");
        require(sp_upgradeRequest.validAt <= block.timestamp, "too early");
        bytes8 version = sp_upgradeRequest.version;
        s_wallets_version[sp_sw.addr] = version;
        IProxy(msg.sender).init(owner, s_versions_code[version]);
        IStorage(msg.sender).migrate();
        emit WalletUpgraded(sp_sw.addr, version);
    }

    function addVersion(address target, address targetOracle)
        external
        multiSig2of3(0)
    {
        require(target != address(0), "no version");
        require(targetOracle != address(0), "no oracle version");
        require(
            IOracle(targetOracle).initialized() != false,
            "oracle not initialized"
        );
        bytes8 version = IStorage(target).version();
        require(
            IOracle(targetOracle).version() == version,
            "version mistmatch"
        );
        address code = s_versions_code[version];
        require(code == address(0), "version exists");
        require(s_versions_oracle[version] == address(0), "oracle exists");
        s_versions_code[version] = target;
        s_versions_oracle[version] = targetOracle;
        emit VersionAdded(version, code, targetOracle);
    }

    function deployVersion(bytes8 version) external multiSig2of3(0) {
        address code = s_versions_code[version];
        require(code != address(0), "version not exist");
        address oracleAddress = s_versions_oracle[version];
        require(oracleAddress != address(0), "oracle not exist");
        s_production_version = version;
        s_production_version_code = code;
        s_production_version_oracle = oracleAddress;
        emit VersionDeployed(version, code, oracleAddress);
    }

    function restoreWalletConfiguration() external {
        Wallet storage sp_sw = s_accounts_wallet[msg.sender];
        require(sp_sw.addr != address(0), "no wallet");
        require(sp_sw.owner == true, "not wallet owner");
        bytes8 version = s_wallets_version[sp_sw.addr];
        if (version == LATEST) {
            version = s_production_version;
        }
        address code = s_versions_code[version];
        require(code != address(0), "version not exist");
        IProxy(sp_sw.addr).init(msg.sender, code);
        emit WalletConfigurationRestored(sp_sw.addr, version, msg.sender);
    }

    function restoreWalletOwnership() external {
        Wallet storage sp_sw = s_accounts_wallet[msg.sender];
        require(sp_sw.addr != address(0), "no wallet");
        require(sp_sw.owner == true, "not wallet owner");

        IProxy(sp_sw.addr).init(msg.sender, address(0));
        emit WalletOwnershipRestored(sp_sw.addr, msg.sender);
    }

    function restoreWalletVersion() external {
        Wallet storage sp_sw = s_accounts_wallet[msg.sender];
        require(sp_sw.addr != address(0), "no wallet");
        require(sp_sw.owner == true, "not wallet owner");

        bytes8 version = s_wallets_version[sp_sw.addr];
        if (version == LATEST) {
            version = s_production_version;
        }
        address code = s_versions_code[version];
        require(code != address(0), "no version");
        IProxy(sp_sw.addr).init(address(0), code);
        emit WalletVersionRestored(sp_sw.addr, version, msg.sender);
    }

    function getLatestVersion() external view returns (address) {
        return s_production_version_code;
    }

    function getWallet(address account) external view returns (address) {
        return s_accounts_wallet[account].addr;
    }

    function getWalletDebt(address account) external view returns (uint88) {
        return s_accounts_wallet[account].debt;
    }

    function createWallet(bool autoMode) external returns (address) {
        require(address(s_swProxy) != address(0), "no proxy");
        require(s_production_version_code != address(0), "no prod version"); //Must be here - ProxyLatest also needs it.
        Wallet storage sp_sw = s_accounts_wallet[msg.sender];
        if (sp_sw.addr == address(0)) {
            sp_sw.addr = _createWallet(address(this), address(s_swProxy));
            require(sp_sw.addr != address(0), "wallet not created");
            sp_sw.owner = true;
            if (autoMode) {
                require(
                    address(s_swProxyLatest) != address(0),
                    "no auto version"
                );
                require(
                    s_versions_code[LATEST] == address(s_swProxyLatest),
                    "incorrect auto version"
                );
                s_wallets_version[sp_sw.addr] = LATEST;
                IProxy(sp_sw.addr).init(msg.sender, address(s_swProxyLatest));
                IStorage(sp_sw.addr).migrate();
                emit WalletCreated(sp_sw.addr, LATEST, msg.sender);
            } else {
                s_wallets_version[sp_sw.addr] = s_production_version;
                IProxy(sp_sw.addr).init(msg.sender, s_production_version_code);
                IStorage(sp_sw.addr).migrate();
                emit WalletCreated(
                    sp_sw.addr,
                    s_production_version,
                    msg.sender
                );
            }
        }
        return sp_sw.addr;
    }

    function oracle() external view returns (address oracleAddress) {
        bytes8 version = s_wallets_version[msg.sender];
        if (version == LATEST) {
            version = s_production_version;
        }
        oracleAddress = s_versions_oracle[version];
    }

    // function setActivator(address newActivator) external multiSig2of3(0) {
    //   s_activator = newActivator;
    // }

    // function setOperator(address newOperator) external multiSig2of3(0) {
    //   s_operator = newOperator;
    // }

    // function setLocalEns(string calldata ens, address dest) external {
    //     s_local_ens[keccak256(abi.encodePacked("@",ens))] = dest;
    // }

    // Batch Call: External Contract Functions
    function batchCallPacked(
        Call[] calldata tr,
        uint256 nonceGroup,
        uint256 silentRevert
    ) external {
        unchecked {
            require(msg.sender == s_activator, "Wallet: sender not allowed");
            uint256 nonce = s_nonce_group[nonceGroup] + (nonceGroup << 232);
            uint256 maxNonce = 0;
            // uint256 length = tr.length;
            uint256 constGas = (21000 + msg.data.length * 8) / tr.length;
            for (uint256 i = 0; i < tr.length; i++) {
                uint256 gas = gasleft();

                Call calldata call = tr[i];
                address to = call.to;
                // uint256 value = call.value;
                uint256 sessionId = call.sessionId;
                uint256 gasLimit = uint32(sessionId >> 80);

                if (i == 0) {
                    require(
                        sessionId >> 192 >= nonce >> 192,
                        "Factory: group+nonce too low"
                    );
                } else {
                    if (sessionId & FLAG_ORDERED != 0) {
                        // ordered
                        require(
                            uint40(maxNonce >> 192) < uint40(sessionId >> 192),
                            "Factory: should be ordered"
                        );
                    }
                }

                if (maxNonce < sessionId) {
                    maxNonce = sessionId;
                }

                require(
                    tx.gasprice <= uint64(sessionId >> 16), /*gasPriceLimit*/
                    "Factory: gas price too high"
                );
                require(
                    block.timestamp > uint40(sessionId >> 152), /*afterTS*/
                    "Factory: too early"
                );
                require(
                    block.timestamp < uint40(sessionId >> 112), /*beforeTS*/
                    "Factory: too late"
                );

                bytes32 trHash = keccak256(
                    abi.encode(
                        BATCH_CALL_PACKED_TYPEHASH,
                        to,
                        call.value,
                        sessionId >> 8,
                        call.data
                    )
                );
                bytes32 messageHash = _messageToRecover(
                    trHash,
                    sessionId & FLAG_EIP712 != 0
                );

                Wallet storage wallet = _getWalletFromMessage(
                    call.signer,
                    messageHash,
                    uint8(sessionId), /*v*/
                    call.r,
                    call.s
                );

                require(wallet.owner == true, "Factory: singer is not owner");

                (bool success, bytes memory res) = sessionId & FLAG_STATICCALL >
                    0
                    ? wallet.addr.call{
                        gas: gasLimit == 0 || gasLimit > gasleft()
                            ? gasleft()
                            : gasLimit
                    }(
                        abi.encodeWithSignature(
                            "staticcall(address,bytes,bytes32)",
                            to,
                            call.data,
                            sessionId & FLAG_CANCELABLE > 0
                                ? messageHash
                                : bytes32(0)
                        )
                    )
                    : wallet.addr.call{
                        gas: gasLimit == 0 || gasLimit > gasleft()
                            ? gasleft()
                            : gasLimit
                    }(
                        abi.encodeWithSignature(
                            "call(address,uint256,bytes,bytes32)",
                            to,
                            call.value,
                            call.data,
                            sessionId & FLAG_CANCELABLE > 0
                                ? messageHash
                                : bytes32(0)
                        )
                    );
                if (!success) {
                    if (silentRevert != 0) {
                        emit BatchCallPackedReverted(wallet.addr, nonce, i);
                        continue;
                    } else {
                        revert(_getRevertMsg(res));
                    }
                }
                if (sessionId & FLAG_PAYMENT != 0 && success) {
                    wallet.debt += _calcRefund(
                        wallet.debt,
                        gas,
                        constGas,
                        uint64(sessionId >> 16)
                    );
                    // if (payment == 0xf000) {
                    //   wallet.debt = uint88(/*(tx.gasprice + (gasPriceLimit - tx.gasprice) / 2) * */ (gas - gasleft() + 16000 + (32000/length))*110/100);
                    // } else {
                    //   wallet.debt = uint88((tx.gasprice + (gasPriceLimit - tx.gasprice) / 2) * (gas - gasleft() + 16000 + (32000/length))*110/100);
                    // }
                }
            }
            require(
                maxNonce < nonce + (1 << 216),
                "Factory: gourp+nonce too high"
            );
            s_nonce_group[nonceGroup] =
                (maxNonce &
                    0x000000ffffffffff000000000000000000000000000000000000000000000000) +
                (1 << 192);
            emit BatchTransfered(5, block.number, maxNonce);
        }
    }

    // Batch Call: Multi External Contract Functions
    function batchMultiCallPacked(MCalls[] calldata tr, uint256 nonceGroup)
        external
    {
        unchecked {
            require(msg.sender == s_activator, "Wallet: sender not allowed");
            uint256 nonce = s_nonce_group[nonceGroup] +
                (uint256(nonceGroup) << 232);
            uint256 maxNonce = 0;
            // uint256 trLength = tr.length;
            uint256 constGas = (21000 + msg.data.length * 8) / tr.length;
            for (uint256 i = 0; i < tr.length; i++) {
                uint256 gas = gasleft();
                MCalls calldata mcalls = tr[i];
                bytes memory msgPre = abi.encode(
                    0x20,
                    mcalls.mcall.length,
                    32 * mcalls.mcall.length
                );
                bytes memory msg2;
                uint256 sessionId = mcalls.sessionId;
                uint256 gasPriceLimit = uint64(sessionId >> 16);

                if (i == 0) {
                    require(
                        sessionId >> 192 >= nonce >> 192,
                        "Factory: group+nonce too low"
                    );
                } else {
                    if (sessionId & FLAG_ORDERED > 0) {
                        require(
                            uint40(maxNonce >> 192) < uint40(sessionId >> 192),
                            "Factory: should be ordered"
                        );
                    }
                }

                if (maxNonce < sessionId) {
                    maxNonce = sessionId;
                }

                require(
                    tx.gasprice <= gasPriceLimit,
                    "Factory: gas price too high"
                );
                require(
                    block.timestamp > uint40(sessionId >> 152), /*afterTS*/
                    "Factory: too early"
                );
                require(
                    block.timestamp < uint40(sessionId >> 112), /*beforeTS*/
                    "Factory: too late"
                );
                uint256 length = mcalls.mcall.length;
                for (uint256 j = 0; j < length; j++) {
                    MCall calldata call = mcalls.mcall[j];
                    address to = call.to;
                    msg2 = abi.encodePacked(
                        msg2,
                        abi.encode(
                            BATCH_MULTI_CALL_TYPEHASH,
                            to,
                            call.value,
                            sessionId,
                            call.data
                        )
                    );
                    if (j < mcalls.mcall.length - 1) {
                        msgPre = abi.encodePacked(
                            msgPre,
                            msg2.length + 32 * mcalls.mcall.length
                        );
                    }
                }

                bytes32 messageHash = _messageToRecover(
                    keccak256(abi.encodePacked(msgPre, msg2)),
                    sessionId & FLAG_EIP712 != 0
                );

                Wallet storage wallet = _getWalletFromMessage(
                    mcalls.signer,
                    messageHash,
                    mcalls.v,
                    mcalls.r,
                    mcalls.s
                );
                require(wallet.owner == true, "Factory: singer is not owner");

                uint256 localNonce;
                uint256 localIndex;
                {
                    localNonce = nonce;
                    localIndex = i;
                }

                if (sessionId & FLAG_CANCELABLE == 0) {
                    messageHash = bytes32(0);
                }

                for (uint256 j = 0; j < length; j++) {
                    MCall calldata call = mcalls.mcall[j];
                    uint32 gasLimit = call.gasLimit;
                    uint16 flags = call.flags;

                    (bool success, bytes memory res) = call.flags &
                        FLAG_STATICCALL >
                        0
                        ? wallet.addr.call{
                            gas: gasLimit == 0 || gasLimit > gasleft()
                                ? gasleft()
                                : gasLimit
                        }(
                            abi.encodeWithSignature(
                                "staticcall(address,bytes,bytes32)",
                                call.to,
                                call.data,
                                messageHash
                            )
                        )
                        : wallet.addr.call{
                            gas: gasLimit == 0 || gasLimit > gasleft()
                                ? gasleft()
                                : gasLimit
                        }(
                            abi.encodeWithSignature(
                                "call(address,uint256,bytes,bytes32)",
                                call.to,
                                call.value,
                                call.data,
                                messageHash
                            )
                        );
                    if (!success) {
                        emit BatchMultiCallPackedFailed(
                            wallet.addr,
                            localNonce,
                            localIndex,
                            j
                        );
                        if (flags & ON_FAIL_CONTINUE > 0) {
                            continue;
                        } else if (flags & ON_FAIL_STOP > 0) {
                            break;
                        }
                        revert(_getRevertMsg(res));
                    } else if (flags & ON_SUCCESS_STOP > 0) {
                        break;
                    } else if (flags & ON_SUCCESS_REVERT > 0) {
                        revert("Factory: revert on success");
                    }
                }
                if (sessionId & FLAG_PAYMENT > 0) {
                    wallet.debt += _calcRefund(
                        wallet.debt,
                        gas,
                        constGas,
                        gasPriceLimit
                    );
                    // wallet.debt = (wallet.debt > 0  ? uint88(/*(tx.gasprice + (gasPriceLimit - tx.gasprice) / 2) * */ (gas - gasleft() + constGas + 5000)):
                    // uint88(/*(tx.gasprice + (gasPriceLimit - tx.gasprice) / 2) * */ (gas - gasleft() + constGas + 22100))) * 110 / 100;
                    // wallet.debt = uint88(/*(tx.gasprice + (gasPriceLimit - tx.gasprice) / 2) * */ (gas - gasleft() + 18000 + (30000/trLength))*110/100);
                    // wallet.debt = uint88(/*(tx.gasprice + (gasPriceLimit - tx.gasprice) / 2) * */ (gas - gasleft() + 16000 + (32000/trLength))*110/100);
                }
            }
            require(
                maxNonce < nonce + (1 << 216),
                "Factory: gourp+nonce too high"
            );
            s_nonce_group[nonceGroup] =
                (maxNonce &
                    0x000000ffffffffff000000000000000000000000000000000000000000000000) +
                (1 << 192);
            emit BatchTransfered(6, block.number, maxNonce);
        }
    }

    // Batch Call: Multi Signature, Multi External Contract Functions
    function batchMultiSigCallPacked(MSCalls[] calldata tr, uint256 nonceGroup)
        external
    {
        unchecked {
            require(msg.sender == s_activator, "Wallet: sender not allowed");
            uint256 nonce = s_nonce_group[nonceGroup] +
                (uint256(nonceGroup) << 232);
            uint256 maxNonce = 0;
            // uint256 trLength = tr.length;
            uint256 constGas = (21000 + msg.data.length * 8) / tr.length;
            for (uint256 i = 0; i < tr.length; i++) {
                uint256 gas = gasleft();
                MSCalls calldata mcalls = tr[i];
                uint256 sessionId = mcalls.sessionId;
                bytes32 messageHash;
                uint256 length = mcalls.mcall.length;
                address[] memory signers = new address[](length);
                {
                    bytes memory msg2 = abi.encode(
                        BATCH_MULTI_SIG_CALL_TYPEHASH,
                        keccak256(
                            abi.encode(
                                BATCH_MULTI_SIG_CALL_LIMITS_TYPEHASH,
                                sessionId
                            )
                        )
                    );

                    if (i == 0) {
                        require(
                            sessionId >> 192 >= nonce >> 192,
                            "Factory: group+nonce too low"
                        );
                    } else {
                        if (sessionId & FLAG_ORDERED > 0) {
                            require(
                                uint40(maxNonce >> 192) <
                                    uint40(sessionId >> 192),
                                "Factory: should be ordered"
                            );
                        }
                    }

                    if (maxNonce < sessionId) {
                        maxNonce = sessionId;
                    }

                    require(
                        tx.gasprice <= uint64(sessionId >> 16), /*gasPriceLimit*/
                        "Factory: gas price too high"
                    );
                    require(
                        block.timestamp > uint40(sessionId >> 152), /*afterTS*/
                        "Factory: too early"
                    );
                    require(
                        block.timestamp < uint40(sessionId >> 112), /*beforeTS*/
                        "Factory: too late"
                    );

                    for (uint256 j = 0; j < length; j++) {
                        MSCall calldata call = mcalls.mcall[j];
                        msg2 = abi.encodePacked(
                            msg2,
                            keccak256(
                                abi.encode(
                                    BATCH_MULTI_SIG_CALL_TRANSACTION_TYPEHASH,
                                    call.signer,
                                    call.to,
                                    call.value,
                                    call.gasLimit,
                                    call.flags,
                                    call.data
                                )
                            )
                        );
                    }

                    messageHash = _messageToRecover(
                        keccak256(msg2),
                        sessionId & FLAG_EIP712 > 0
                    );

                    for (uint256 s = 0; s < mcalls.signatures.length; ++s) {
                        Signature calldata signature = mcalls.signatures[s];
                        for (uint256 j = 0; j < length; j++) {
                            MSCall calldata call = mcalls.mcall[j];
                            address signer = _addressFromMessageAndSignature(
                                messageHash,
                                signature.v,
                                signature.r,
                                signature.s
                            );
                            if (
                                signer == call.signer &&
                                signers[j] == address(0)
                            ) {
                                signers[j] = signer;
                            }
                        }
                    }
                }
                uint256 localConstGas;
                uint256 localNonce;
                {
                    localConstGas = constGas;
                    localNonce = nonce;
                }

                if (sessionId & FLAG_CANCELABLE == 0) {
                    messageHash = bytes32(0);
                }

                for (uint256 j = 0; j < length; j++) {
                    require(
                        signers[j] != address(0),
                        "Factory: signer missing"
                    );
                    Wallet storage wallet = s_accounts_wallet[signers[j]];
                    require(
                        wallet.owner == true,
                        "Factory: signer is not owner"
                    );
                    MSCall calldata call = mcalls.mcall[j];
                    bytes32 localMessageHash;
                    uint256 localIndex;
                    uint256 localGas;
                    uint256 localSessionId;
                    {
                        localMessageHash = messageHash;
                        localIndex = i;
                        localGas = gas;
                        localSessionId = sessionId;
                    }
                    // address to = call.to;

                    (bool success, bytes memory res) = call.flags &
                        FLAG_STATICCALL >
                        0
                        ? wallet.addr.call{
                            gas: call.gasLimit == 0 || call.gasLimit > gasleft()
                                ? gasleft()
                                : call.gasLimit
                        }(
                            abi.encodeWithSignature(
                                "staticcall(address,bytes,bytes32)",
                                call.to,
                                call.data,
                                localMessageHash
                            )
                        )
                        : wallet.addr.call{
                            gas: call.gasLimit == 0 || call.gasLimit > gasleft()
                                ? gasleft()
                                : call.gasLimit
                        }(
                            abi.encodeWithSignature(
                                "call(address,uint256,bytes,bytes32)",
                                call.to,
                                call.value,
                                call.data,
                                localMessageHash
                            )
                        );
                    if (!success) {
                        emit BatchMultiSigCallPackedFailed(
                            wallet.addr,
                            localNonce,
                            localIndex,
                            j
                        );
                        if (call.flags & ON_FAIL_CONTINUE > 0) {
                            continue;
                        } else if (call.flags & ON_FAIL_STOP > 0) {
                            break;
                        }
                        revert(_getRevertMsg(res));
                    } else if (call.flags & ON_SUCCESS_STOP > 0) {
                        break;
                    } else if (call.flags & ON_SUCCESS_REVERT > 0) {
                        revert("Factory: revert on success");
                    }
                    if (
                        localSessionId & FLAG_PAYMENT > 0 /*refund*/
                    ) {
                        wallet.debt += _calcRefund(
                            wallet.debt,
                            localGas,
                            localConstGas,
                            uint64(localSessionId >> 16) /*gasPriceLimit*/
                        );
                    }
                }
            }
            require(
                maxNonce < nonce + (1 << 216),
                "Factory: gourp+nonce too high"
            );
            s_nonce_group[nonceGroup] =
                (maxNonce &
                    0x000000ffffffffff000000000000000000000000000000000000000000000000) +
                (1 << 192);
            emit BatchTransfered(7, block.number, maxNonce);
        }
    }

    function _calcRefund(
        uint256 debt,
        uint256 gas,
        uint256 constGas,
        uint256 gasPriceLimit
    ) private view returns (uint88) {
        return (
            debt > 0
                ? uint88(
                    (tx.gasprice + (gasPriceLimit - tx.gasprice) / 2) *
                        (((gas - gasleft()) * 110) / 100 + constGas + 5000)
                )
                : uint88(
                    (tx.gasprice + (gasPriceLimit - tx.gasprice) / 2) *
                        (((gas - gasleft()) * 110) / 100 + constGas + 8000)
                )
        );
        // uint88(/*(tx.gasprice + (gasPriceLimit - tx.gasprice) / 2) * */ (gas - gasleft() + constGas + 15000) /*22100))*/ * 110 / 100 ));
    }

    function _createWallet(address creator, address target)
        private
        returns (address result)
    {

            bytes memory code
         = hex"60998061000d6000396000f30036601657341560145734602052336001602080a25b005b6000805260046000601c376302d05d3f6000511415604b5773dadadadadadadadadadadadadadadadadadadada602052602080f35b366000803760008036600073bebebebebebebebebebebebebebebebebebebebe5af415608f57341560855734602052600051336002602080a35b3d6000803e3d6000f35b3d6000803e3d6000fd"; //log3-event-ids-address-funcid-opt (-2,-2) (min: 22440)
        bytes20 creatorBytes = bytes20(creator);
        bytes20 targetBytes = bytes20(target);
        for (uint256 i = 0; i < 20; i++) {
            code[61 + i] = creatorBytes[i];
            code[101 + i] = targetBytes[i];
        }
        assembly {
            result := create(0, add(code, 0x20), mload(code))
        }
    }
}
