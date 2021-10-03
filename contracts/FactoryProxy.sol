// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v2;

import "./FactoryStorage.sol";
// 1-15     16bit flags
uint256 constant GAS_PRICE_LIMIT_BIT = 16; // 16-70    64bit gas price limit
uint256 constant GAS_LIMIT_BIT = 80; // 80-111   32bit gas limit
uint256 constant BEFORE_TS_BIT = 112; // 112-151  40bit before timestamp
uint256 constant AFTER_TS_BIT = 152; // 152-191  40bit after timestamp
uint256 constant NONCE_BIT = 192; // 192-231  40bit nonce
uint256 constant MAX_NONCE_JUMP_BIT = 216; // 216      24bit of nonce
uint256 constant GROUP_BIT = 232; // 232-255  24bit group

struct Signature {
    bytes32 r;
    bytes32 s;
    uint8 v;
}

struct Transfer {
    address signer;
    bytes32 r;
    bytes32 s;
    address token;
    bytes32 tokenEnsHash;
    address to;
    bytes32 toEnsHash;
    uint256 value;
    uint256 sessionId;
}

struct PackedTransfer {
    address signer;
    bytes32 r;
    bytes32 s;
    address token;
    address to;
    uint256 value;
    uint256 sessionId;
}

struct Call {
    bytes32 r;
    bytes32 s;
    bytes32 typeHash;
    address to;
    bytes32 ensHash;
    uint256 value;
    uint256 sessionId;
    address signer;
    bytes32 functionSignature;
    bytes data;
}

struct PackedCall {
    bytes32 r;
    bytes32 s;
    address to;
    uint256 value;
    uint256 sessionId;
    address signer;
    bytes data;
}

struct MCall {
    bytes32 typeHash;
    bytes32 ensHash;
    uint256 value;
    bytes32 functionSignature;
    address to;
    uint32 gasLimit;
    uint16 flags;
    bytes data;
}

struct MCalls {
    bytes32 r;
    bytes32 s;
    bytes32 typeHash;
    uint256 sessionId;
    address signer;
    uint8 v;
    MCall[] mcall;
}

struct PackedMCall {
    uint256 value;
    address to;
    uint32 gasLimit;
    uint16 flags;
    bytes data;
}

struct PackedMCalls {
    bytes32 r;
    bytes32 s;
    uint256 sessionId;
    address signer;
    uint8 v;
    PackedMCall[] mcall;
}

struct MSCall {
    bytes32 typeHash;
    bytes32 ensHash;
    bytes32 functionSignature;
    uint256 value;
    address signer;
    uint32 gasLimit;
    uint16 flags;
    address to;
    bytes data;
}

struct MSCalls {
    bytes32 typeHash;
    uint256 sessionId;
    MSCall[] mcall;
    Signature[] signatures;
}

struct PackedMSCall {
    uint256 value;
    address signer;
    uint32 gasLimit;
    uint16 flags;
    address to;
    bytes data;
}

struct PackedMSCalls {
    uint256 sessionId;
    PackedMSCall[] mcall;
    Signature[] signatures;
}

struct MultiSigCallLocals {
    bytes32 messageHash;
    uint256 constGas;
    uint256 gas;
    uint256 index;
}

contract FactoryProxy is FactoryStorage {
    uint8 public constant VERSION_NUMBER = 0x1;

    string public constant NAME = "Kirobo Deployer";

    string public constant VERSION = "1";

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

    bytes32 public constant PACKED_BATCH_MULTI_SIG_CALL_LIMITS_TYPEHASH =
        keccak256("Limits(uint256 sessionId)");

    bytes32 public constant PACKED_BATCH_MULTI_SIG_CALL_TRANSACTION_TYPEHASH =
        keccak256(
            "Transaction(address signer,address to,uint256 value,uint32 gasLimit,uint16 flags,bytes data)"
        );

    bytes32 public constant BATCH_TRANSFER_TYPEHASH =
        keccak256(
            "BatchTransfer(address token_address,string token_ens,address to,string to_ens,uint256 value,uint64 nonce,uint40 valid_from,uint40 expires_at,uint32 gas_limit,uint64 gas_price_limit,bool refund)"
        );

    bytes32 public constant BATCH_CALL_TRANSACTION_TYPEHASH =
        keccak256(
            "Transaction(address call_address,string call_ens,uint256 eth_value,uint64 nonce,uint40 valid_from,uint40 expires_at,uint32 gas_limit,uint64 gas_price_limit,bool view_only,bool refund,string method_interface)"
        );

    bytes32 public constant BATCH_MULTI_CALL_LIMITS_TYPEHASH =
        keccak256(
            "Limits(uint64 nonce,bool refund,uint40 valid_from,uint40 expires_at,uint64 gas_price_limit)"
        );

    bytes32 public constant BATCH_MULTI_CALL_TRANSACTION_TYPEHASH =
        keccak256(
            "Transaction(address call_address,string call_ens,uint256 eth_value,uint32 gas_limit,bool view_only,bool continue_on_fail,bool stop_on_fail,bool stop_on_success,bool revert_on_success,string method_interface)"
        );

    bytes32 public constant BATCH_MULTI_SIG_CALL_LIMITS_TYPEHASH =
        keccak256(
            "Limits(uint64 nonce,bool refund,uint40 valid_from,uint40 expires_at,uint64 gas_price_limit)"
        );

    bytes32 public constant BATCH_MULTI_SIG_CALL_TRANSACTION_TYPEHASH =
        keccak256(
            "Transaction(address signer,address call_address,string call_ens,uint256 eth_value,uint32 gas_limit,bool view_only,bool continue_on_fail,bool stop_on_fail,bool stop_on_success,bool revert_on_success,string method_interface)"
        );

    bytes32 public constant BATCH_MULTI_SIG_CALL_APPROVAL_TYPEHASH =
        keccak256("Approval(address signer)");

    bytes32 public constant BATCH_TRANSFER_PACKED_TYPEHASH =
        keccak256(
            "BatchTransferPacked(address token,address to,uint256 value,uint256 sessionId)"
        );

    // event ErrorHandled(bytes reason);
    event TransferReverted(
        address indexed wallet,
        uint256 nonce,
        uint256 index
    );
    event TransferPackedReverted(
        address indexed wallet,
        uint256 nonce,
        uint256 index
    );
    event BatchCallReverted(
        address indexed wallet,
        uint256 nonce,
        uint256 index
    );
    event BatchCallPackedReverted(
        address indexed wallet,
        uint256 nonce,
        uint256 index
    );
    event BatchMultiCallFailed(
        address indexed wallet,
        uint256 nonce,
        uint256 index,
        uint256 innerIndex
    );
    event BatchMultiCallPackedFailed(
        address indexed wallet,
        uint256 nonce,
        uint256 index,
        uint256 innerIndex
    );
    event BatchMultiSigCallFailed(
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

    constructor(ENS ens) FactoryStorage() {
        s_ens = ens;

        uint256 chainId;
        assembly {
            chainId := chainid()
        }

        s_uid = bytes32(
            (uint256(VERSION_NUMBER) << 248) |
                ((uint256(blockhash(block.number - 1)) << 192) >> 16) |
                uint256(uint160(address(this)))
        );

        CHAIN_ID = chainId;

        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract,bytes32 salt)"
                ),
                keccak256(bytes(NAME)),
                keccak256(bytes(VERSION)),
                chainId,
                address(this),
                s_uid
            )
        );
    }

    fallback() external {
        assembly {
            calldatacopy(0x00, 0x00, calldatasize())
            let res := delegatecall(
                gas(),
                sload(s_target.slot),
                0x00,
                calldatasize(),
                0,
                0
            )
            returndatacopy(0x00, 0x00, returndatasize())
            if res {
                return(0x00, returndatasize())
            }
            revert(0x00, returndatasize())
        }
    }

    function setTarget(address target) external onlyOwner {
        require(s_frozen != true, "frozen");
        require(target != address(0), "no target");
        s_target = target;
    }

    function freezeTarget() external onlyOwner {
        s_frozen = true;
    }

    function setActivator(address newActivator) external onlyOwner {
        s_activator = newActivator;
    }

    function setLocalEns(string calldata ens, address dest) external onlyOwner {
        s_local_ens[keccak256(abi.encodePacked("@", ens))] = dest;
    }

    function collectDebt(address account, address recipient) external {
        unchecked {
            require(msg.sender == s_activator, "Wallet: sender not allowed");
            Wallet storage wallet = s_accounts_wallet[account];
            uint256 debt = wallet.debt;
            if (debt > 0) {
                wallet.debt = 0;
                (bool success, bytes memory res) = wallet.addr.call(
                    abi.encodeWithSignature(
                        "transferEth(address,uint256,bytes32)",
                        recipient,
                        debt,
                        bytes32(0)
                    )
                );
                if (!success) {
                    revert(_getRevertMsg(res));
                }
            }
        }
    }

    // Batch Transfers: ETH & ERC20 Tokens
    function batchTransfer(
        Transfer[] calldata tr,
        uint24 nonceGroup,
        bool silentRevert
    ) external {
        require(msg.sender == s_activator, "Wallet: sender not allowed");
        unchecked {
            uint256 ng = nonceGroup;
            uint256 nonce = s_nonce_group[ng] + (ng << GROUP_BIT);
            uint256 maxNonce = 0;
            uint256 constGas = (21000 + msg.data.length * 8) / tr.length;
            for (uint256 i = 0; i < tr.length; i++) {
                uint256 gas = gasleft();
                Transfer calldata call = tr[i];
                address to = _ensToAddress(call.toEnsHash, call.to);
                address token = _ensToAddress(call.tokenEnsHash, call.token);
                uint256 sessionId = call.sessionId;
                uint256 gasLimit = uint32(sessionId >> GAS_LIMIT_BIT);

                _checkSessionIdLimits(i, sessionId, nonce, maxNonce);
                maxNonce = sessionId;

                bytes32 messageHash = _messageToRecover(
                    _encodeTransfer(call),
                    sessionId & FLAG_EIP712 != 0
                );

                Wallet storage wallet = _getWalletFromMessage(
                    call.signer,
                    messageHash,
                    uint8(sessionId), /*v*/
                    call.r,
                    call.s
                );

                require(wallet.owner, "Factory: signer is not owner");

                (bool success, bytes memory res) = call.token == address(0)
                    ? wallet.addr.call{
                        gas: gasLimit == 0 || gasLimit > gasleft()
                            ? gasleft()
                            : gasLimit
                    }(
                        abi.encodeWithSignature(
                            "transferEth(address,uint256,bytes32)",
                            to,
                            call.value,
                            sessionId & FLAG_CANCELABLE != 0
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
                            "transferERC20(address,address,uint256,bytes32)",
                            token,
                            to,
                            call.value,
                            sessionId & FLAG_CANCELABLE != 0
                                ? messageHash
                                : bytes32(0)
                        )
                    );
                if (!success) {
                    if (!silentRevert) {
                        emit TransferReverted(wallet.addr, nonce, i);
                        continue;
                    } else {
                        revert(_getRevertMsg(res));
                    }
                }

                if (sessionId & FLAG_PAYMENT != 0 && success) {
                    wallet.debt += _calcRefund(
                        wallet.debt,
                        gas,
                        constGas + 12000,
                        uint64(sessionId >> 16)
                    );
                }
            }
            s_nonce_group[ng] = _nextNonce(nonce, maxNonce);
            emit BatchTransfered(0, block.number, maxNonce);
        }
    }

    // Batch Transfers: ETH & ERC20 Tokens
    function batchTransferPacked(
        PackedTransfer[] calldata tr,
        uint24 nonceGroup,
        bool silentRevert
    ) external {
        require(msg.sender == s_activator, "Wallet: sender not allowed");
        unchecked {
            uint256 ng = nonceGroup;
            uint256 nonce = s_nonce_group[ng] + (ng << GROUP_BIT);
            uint256 maxNonce = 0;
            uint256 constGas = (21000 + msg.data.length * 8) / tr.length;
            for (uint256 i = 0; i < tr.length; i++) {
                uint256 gas = gasleft();
                PackedTransfer calldata call = tr[i];
                address to = call.to;
                uint256 sessionId = call.sessionId;
                uint256 gasLimit = uint32(sessionId >> GAS_LIMIT_BIT);

                _checkSessionIdLimits(i, sessionId, nonce, maxNonce);
                maxNonce = sessionId;

                bytes32 messageHash = _messageToRecover(
                    keccak256(
                        abi.encode(
                            BATCH_TRANSFER_PACKED_TYPEHASH,
                            call.token,
                            to,
                            call.value,
                            sessionId >> 8
                        )
                    ),
                    sessionId & FLAG_EIP712 != 0
                );

                Wallet storage wallet = _getWalletFromMessage(
                    call.signer,
                    messageHash,
                    uint8(sessionId), /*v*/
                    call.r,
                    call.s
                );

                require(wallet.owner, "Factory: signer is not owner");

                uint256 localNonce;
                bool localSilentRevert;
                {
                    localNonce = nonce;
                    localSilentRevert = silentRevert;
                }

                (bool success, bytes memory res) = call.token == address(0)
                    ? wallet.addr.call{
                        gas: gasLimit == 0 || gasLimit > gasleft()
                            ? gasleft()
                            : gasLimit
                    }(
                        abi.encodeWithSignature(
                            "transferEth(address,uint256,bytes32)",
                            to,
                            call.value,
                            sessionId & FLAG_CANCELABLE != 0
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
                            "transferERC20(address,address,uint256,bytes32)",
                            call.token,
                            to,
                            call.value,
                            sessionId & FLAG_CANCELABLE != 0
                                ? messageHash
                                : bytes32(0)
                        )
                    );
                if (!success) {
                    if (!localSilentRevert) {
                        emit TransferPackedReverted(wallet.addr, localNonce, i);
                        continue;
                    } else {
                        revert(_getRevertMsg(res));
                    }
                }

                if (sessionId & FLAG_PAYMENT != 0 && success) {
                    wallet.debt += _calcRefund(
                        wallet.debt,
                        gas,
                        constGas + 12000,
                        uint64(sessionId >> 16)
                    );
                }
            }
            s_nonce_group[ng] = _nextNonce(nonce, maxNonce);
            emit BatchTransfered(4, block.number, maxNonce);
        }
    }

    function _executeCall(
        address wallet,
        address to,
        uint16 flags,
        uint32 gasLimit,
        bytes32 messageHash,
        bytes32 functionSignature,
        uint256 value,
        bool packed,
        bytes calldata data
    ) private returns (bool, bytes memory) {
        if (flags & FLAG_CANCELABLE != 0) {
            messageHash = bytes32(0);
        }
        return
            flags & FLAG_STATICCALL != 0
                ? wallet.call{
                    gas: gasLimit == 0 || gasLimit > gasleft()
                        ? gasleft()
                        : gasLimit
                }(
                    abi.encodeWithSignature(
                        "LocalStaticCall(address,bytes,bytes32)",
                        to,
                        packed
                            ? data
                            : functionSignature ==
                                0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470
                            ? bytes("")
                            : abi.encodePacked(bytes4(functionSignature), data),
                        messageHash
                    )
                )
                : wallet.call{
                    gas: gasLimit == 0 || gasLimit > gasleft()
                        ? gasleft()
                        : gasLimit
                }(
                    abi.encodeWithSignature(
                        "LocalCall(address,uint256,bytes,bytes32)",
                        to,
                        value,
                        packed
                            ? data
                            : functionSignature ==
                                0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470
                            ? bytes("")
                            : packed
                            ? data
                            : abi.encodePacked(bytes4(functionSignature), data),
                        messageHash
                    )
                );
    }

    function _executeCall(
        address wallet,
        address to,
        uint16 flags,
        uint32 gasLimit,
        bytes32 messageHash,
        bytes32 functionSignature,
        uint256 value,
        bytes calldata data
    ) private returns (bool, bytes memory) {
        return
            _executeCall(
                wallet,
                to,
                flags,
                gasLimit,
                messageHash,
                functionSignature,
                value,
                false,
                data
            );
    }

    function _executePackedCall(
        address wallet,
        address to,
        uint16 flags,
        uint32 gasLimit,
        bytes32 messageHash,
        uint256 value,
        bytes calldata data
    ) private returns (bool, bytes memory) {
        return
            _executeCall(
                wallet,
                to,
                flags,
                gasLimit,
                messageHash,
                bytes32(0),
                value,
                true,
                data
            );
    }

    // Batch Call: External Contract Functions
    function batchCall(
        Call[] calldata tr,
        uint256 nonceGroup,
        bool silentRevert
    ) external {
        require(msg.sender == s_activator, "Wallet: sender not allowed");
        unchecked {
            uint256 ng = nonceGroup;
            uint256 nonce = s_nonce_group[ng] + (ng << GROUP_BIT);
            uint256 maxNonce = 0;
            uint256 constGas = (21000 + msg.data.length * 16) / tr.length;
            for (uint256 i = 0; i < tr.length; i++) {
                uint256 gas = gasleft();

                Call calldata call = tr[i];
                uint256 sessionId = call.sessionId;

                _checkSessionIdLimits(i, sessionId, nonce, maxNonce);

                maxNonce = sessionId;

                (bytes32 callHash, address to) = _encodeCall(call);

                bytes32 messageHash = _messageToRecover(
                    callHash,
                    sessionId & FLAG_EIP712 != 0
                );

                Wallet storage wallet = _getWalletFromMessage(
                    call.signer,
                    messageHash,
                    uint8(sessionId), /*v*/
                    call.r,
                    call.s
                );

                require(wallet.owner, "Factory: signer is not owner");

                (bool success, bytes memory res) = _executeCall(
                    wallet.addr,
                    to,
                    uint16(sessionId),
                    uint32(sessionId >> GAS_LIMIT_BIT),
                    messageHash,
                    call.functionSignature,
                    call.value,
                    call.data
                );
                if (!success) {
                    if (!silentRevert) {
                        emit BatchCallReverted(wallet.addr, nonce, i);
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
                }
            }

            s_nonce_group[ng] = _nextNonce(nonce, maxNonce);
            emit BatchTransfered(1, block.number, maxNonce);
        }
    }

    function batchCallPacked(
        PackedCall[] calldata tr,
        uint256 nonceGroup,
        bool silentRevert
    ) external {
        require(msg.sender == s_activator, "Wallet: sender not allowed");
        unchecked {
            uint256 ng = nonceGroup;
            uint256 nonce = s_nonce_group[ng] + (ng << GROUP_BIT);
            uint256 maxNonce = 0;
            // uint256 length = tr.length;
            uint256 constGas = (21000 + msg.data.length * 8) / tr.length;
            for (uint256 i = 0; i < tr.length; i++) {
                uint256 gas = gasleft();

                PackedCall calldata call = tr[i];
                address to = call.to;
                uint256 sessionId = call.sessionId;

                _checkSessionIdLimits(i, sessionId, nonce, maxNonce);
                maxNonce = sessionId;

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

                require(wallet.owner, "Factory: signer is not owner");

                (bool success, bytes memory res) = _executePackedCall(
                    wallet.addr,
                    to,
                    uint16(sessionId),
                    uint32(sessionId >> GAS_LIMIT_BIT),
                    messageHash,
                    call.value,
                    call.data
                );

                if (!success) {
                    if (!silentRevert) {
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
                }
            }
            s_nonce_group[ng] = _nextNonce(nonce, maxNonce);
            emit BatchTransfered(5, block.number, maxNonce);
        }
    }

    // Batch Call: Multi External Contract Functions
    function batchMultiCall(MCalls[] calldata tr, uint256 nonceGroup) external {
        require(msg.sender == s_activator, "Wallet: sender not allowed");
        unchecked {
            uint256 ng = nonceGroup;
            uint256 nonce = s_nonce_group[ng] + (ng << GROUP_BIT);
            uint256 maxNonce = 0;
            uint256 constGas = (21000 + msg.data.length * 8) / tr.length;
            for (uint256 i = 0; i < tr.length; i++) {
                uint256 gas = gasleft();
                MCalls calldata mcalls = tr[i];
                uint256 sessionId = mcalls.sessionId;
                bytes memory msg2 = abi.encode(
                    mcalls.typeHash,
                    keccak256(
                        abi.encode(
                            BATCH_MULTI_CALL_LIMITS_TYPEHASH,
                            uint64(sessionId >> NONCE_BIT), // group + nonce
                            sessionId & FLAG_PAYMENT != 0,
                            uint40(sessionId >> AFTER_TS_BIT),
                            uint40(sessionId >> BEFORE_TS_BIT),
                            uint64(sessionId >> GAS_PRICE_LIMIT_BIT)
                        )
                    )
                );

                _checkSessionIdLimits(i, sessionId, nonce, maxNonce);
                maxNonce = sessionId;

                uint256 length = mcalls.mcall.length;

                for (uint256 j = 0; j < length; j++) {
                    MCall calldata call = mcalls.mcall[j];
                    uint16 flags = call.flags;

                    bytes32 transactionHash = keccak256(
                        abi.encode(
                            BATCH_MULTI_CALL_TRANSACTION_TYPEHASH,
                            call.to,
                            call.ensHash,
                            call.value,
                            call.gasLimit,
                            flags & FLAG_STATICCALL,
                            flags & ON_FAIL_CONTINUE,
                            flags & ON_FAIL_STOP,
                            flags & ON_SUCCESS_STOP,
                            flags & ON_SUCCESS_REVERT,
                            call.functionSignature
                        )
                    );

                    msg2 = abi.encodePacked(
                        msg2,
                        call.functionSignature !=
                            0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470
                            ? keccak256(
                                abi.encode(
                                    call.typeHash,
                                    transactionHash,
                                    call.data
                                )
                            )
                            : keccak256(
                                abi.encode(call.typeHash, transactionHash)
                            )
                    );
                }

                bytes32 messageHash = _messageToRecover(
                    keccak256(msg2),
                    sessionId & FLAG_EIP712 != 0
                );

                Wallet storage wallet = _getWalletFromMessage(
                    mcalls.signer,
                    messageHash,
                    mcalls.v,
                    mcalls.r,
                    mcalls.s
                );

                require(wallet.owner, "Factory: signer is not owner");

                uint256 localNonce;
                uint256 localIndex;
                bytes32 localMessageHash;

                {
                    localNonce = nonce;
                    localIndex = i;
                    localMessageHash = messageHash;
                }

                for (uint256 j = 0; j < length; j++) {
                    MCall calldata call = mcalls.mcall[j];
                    uint16 flags = call.flags;

                    (bool success, bytes memory res) = _executeCall(
                        wallet.addr,
                        _ensToAddress(call.ensHash, call.to),
                        flags,
                        call.gasLimit,
                        localMessageHash,
                        call.functionSignature,
                        call.value,
                        call.data
                    );

                    if (!success) {
                        emit BatchMultiCallFailed(
                            wallet.addr,
                            localNonce,
                            localIndex,
                            j
                        );
                        if (flags & ON_FAIL_CONTINUE != 0) {
                            continue;
                        } else if (flags & ON_FAIL_STOP != 0) {
                            break;
                        }
                        revert(_getRevertMsg(res));
                    } else if (flags & ON_SUCCESS_STOP != 0) {
                        break;
                    } else if (flags & ON_SUCCESS_REVERT != 0) {
                        revert("Factory: revert on success");
                    }
                }
                if (sessionId & FLAG_PAYMENT != 0) {
                    wallet.debt += _calcRefund(
                        wallet.debt,
                        gas,
                        constGas,
                        uint64(sessionId >> 16) /*gasPriceLimit*/
                    );
                }
            }
            s_nonce_group[ng] = _nextNonce(nonce, maxNonce);
            emit BatchTransfered(2, block.number, maxNonce);
        }
    }

    function batchMultiCallPacked(
        PackedMCalls[] calldata tr,
        uint256 nonceGroup
    ) external {
        require(msg.sender == s_activator, "Wallet: sender not allowed");
        unchecked {
            uint256 ng = nonceGroup;
            uint256 nonce = s_nonce_group[ng] + (ng << GROUP_BIT);
            uint256 maxNonce = 0;
            uint256 constGas = (21000 + msg.data.length * 8) / tr.length;
            for (uint256 i = 0; i < tr.length; i++) {
                uint256 gas = gasleft();
                PackedMCalls calldata mcalls = tr[i];
                bytes memory msgPre = abi.encode(
                    0x20,
                    mcalls.mcall.length,
                    32 * mcalls.mcall.length
                );
                bytes memory msg2;
                uint256 sessionId = mcalls.sessionId;
                uint256 gasPriceLimit = uint64(sessionId >> 16);

                _checkSessionIdLimits(i, sessionId, nonce, maxNonce);
                maxNonce = sessionId;

                uint256 length = mcalls.mcall.length;
                for (uint256 j = 0; j < length; j++) {
                    PackedMCall calldata call = mcalls.mcall[j];
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
                require(wallet.owner, "Factory: signer is not owner");

                uint256 localNonce;
                uint256 localIndex;
                {
                    localNonce = nonce;
                    localIndex = i;
                }

                for (uint256 j = 0; j < length; j++) {
                    PackedMCall calldata call = mcalls.mcall[j];
                    uint16 flags = call.flags;

                    (bool success, bytes memory res) = _executePackedCall(
                        wallet.addr,
                        call.to,
                        flags,
                        call.gasLimit,
                        messageHash,
                        call.value,
                        call.data
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
                }
            }
            s_nonce_group[ng] = _nextNonce(nonce, maxNonce);
            emit BatchTransfered(6, block.number, maxNonce);
        }
    }

    // Batch Call: Multi Signature, Multi External Contract Functions
    function batchMultiSigCall(MSCalls[] calldata tr, uint256 nonceGroup)
        external
    {
        require(msg.sender == s_activator, "Wallet: sender not allowed");
        unchecked {
            uint256 ng = nonceGroup;
            uint256 nonce = s_nonce_group[ng] + (ng << GROUP_BIT);
            uint256 maxNonce = 0;
            uint256 trLength = tr.length;
            uint256 constGas = (21000 + msg.data.length * 8) / trLength;
            for (uint256 i = 0; i < trLength; i++) {
                uint256 gas = gasleft();
                MSCalls calldata mcalls = tr[i];
                uint256 sessionId = mcalls.sessionId;
                bytes memory msg2 = abi.encode(
                    mcalls.typeHash,
                    keccak256(
                        abi.encode(
                            BATCH_MULTI_SIG_CALL_LIMITS_TYPEHASH,
                            uint64(sessionId >> NONCE_BIT), // group + nonce
                            sessionId & FLAG_PAYMENT != 0,
                            uint40(sessionId >> AFTER_TS_BIT),
                            uint40(sessionId >> BEFORE_TS_BIT),
                            uint64(sessionId >> GAS_PRICE_LIMIT_BIT)
                        )
                    )
                );

                _checkSessionIdLimits(i, sessionId, nonce, maxNonce);
                maxNonce = sessionId;

                uint256 length = mcalls.mcall.length;

                for (uint256 j = 0; j < length; j++) {
                    MSCall calldata call = mcalls.mcall[j];

                    msg2 = abi.encodePacked(
                        msg2,
                        // messageHash
                        call.functionSignature !=
                            0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470
                            ? keccak256(
                                abi.encode(
                                    call.typeHash,
                                    _calcMultiSigTransactionHash(call),
                                    call.data
                                )
                            )
                            : call.to != address(0)
                            ? keccak256(
                                abi.encode(
                                    call.typeHash,
                                    _calcMultiSigTransactionHash(call)
                                )
                            )
                            : keccak256(
                                abi.encode(
                                    BATCH_MULTI_SIG_CALL_APPROVAL_TYPEHASH,
                                    call.signer
                                )
                            )
                    );
                }

                bytes32 messageHash = _messageToRecover(
                    keccak256(msg2),
                    sessionId & FLAG_EIP712 != 0
                );

                address[] memory signers = new address[](length);

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
                        if (signer == call.signer && signers[j] == address(0)) {
                            signers[j] = signer;
                        }
                    }
                }

                MultiSigCallLocals memory locals;
                uint256 localSessionId;
                uint256 localNonce;
                {
                    localSessionId = sessionId;
                    localNonce = nonce;
                    locals.index = i;
                    locals.constGas = constGas;
                    locals.gas = gas;
                    if (sessionId & FLAG_CANCELABLE != 0) {
                        locals.messageHash = messageHash;
                    }
                }

                for (uint256 j = 0; j < length; j++) {
                    require(
                        signers[j] != address(0),
                        "Factory: signer missing"
                    );
                    MSCall calldata call = mcalls.mcall[j];
                    if (call.to == address(0)) {
                        continue;
                    }
                    Wallet storage wallet = s_accounts_wallet[signers[j]];
                    require(wallet.owner, "Factory: signer is not owner");

                    (bool success, bytes memory res) = _executeCall(
                        wallet.addr,
                        _ensToAddress(call.ensHash, call.to),
                        call.flags,
                        call.gasLimit,
                        locals.messageHash,
                        call.functionSignature,
                        call.value,
                        call.data
                    );

                    if (!success) {
                        emit BatchMultiSigCallFailed(
                            wallet.addr,
                            localNonce,
                            locals.index,
                            j
                        );
                        if (call.flags & ON_FAIL_CONTINUE != 0) {
                            continue;
                        } else if (call.flags & ON_FAIL_STOP != 0) {
                            break;
                        }
                        revert(_getRevertMsg(res));
                    } else if (call.flags & ON_SUCCESS_STOP != 0) {
                        break;
                    } else if (call.flags & ON_SUCCESS_REVERT != 0) {
                        revert("Factory: revert on success");
                    }
                    if (localSessionId & FLAG_PAYMENT != 0) {
                        wallet.debt += _calcRefund(
                            wallet.debt,
                            locals.gas,
                            locals.constGas,
                            uint64(localSessionId >> 16) /*gasPriceLimit*/
                        );
                    }
                }
            }
            s_nonce_group[ng] = _nextNonce(nonce, maxNonce);
            emit BatchTransfered(3, block.number, maxNonce);
        }
    }

    function batchMultiSigCallPacked(
        PackedMSCalls[] calldata tr,
        uint256 nonceGroup
    ) external {
        require(msg.sender == s_activator, "Wallet: sender not allowed");
        unchecked {
            uint256 ng = nonceGroup;
            uint256 nonce = s_nonce_group[ng] + (ng << GROUP_BIT);
            uint256 maxNonce = 0;
            uint256 constGas = (21000 + msg.data.length * 8) / tr.length;
            for (uint256 i = 0; i < tr.length; i++) {
                uint256 gas = gasleft();
                PackedMSCalls calldata mcalls = tr[i];
                uint256 sessionId = mcalls.sessionId;
                bytes32 messageHash;
                uint256 length = mcalls.mcall.length;
                address[] memory signers = new address[](length);
                {
                    bytes memory msg2 = abi.encode(
                        BATCH_MULTI_SIG_CALL_TYPEHASH,
                        keccak256(
                            abi.encode(
                                PACKED_BATCH_MULTI_SIG_CALL_LIMITS_TYPEHASH,
                                sessionId
                            )
                        )
                    );

                    _checkSessionIdLimits(i, sessionId, nonce, maxNonce);
                    maxNonce = sessionId;

                    for (uint256 j = 0; j < length; j++) {
                        PackedMSCall calldata call = mcalls.mcall[j];
                        msg2 = abi.encodePacked(
                            msg2,
                            keccak256(
                                abi.encode(
                                    PACKED_BATCH_MULTI_SIG_CALL_TRANSACTION_TYPEHASH,
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
                            PackedMSCall calldata call = mcalls.mcall[j];
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

                for (uint256 j = 0; j < length; j++) {
                    require(
                        signers[j] != address(0),
                        "Factory: signer missing"
                    );
                    Wallet storage wallet = s_accounts_wallet[signers[j]];
                    require(wallet.owner, "Factory: signer is not owner");
                    PackedMSCall calldata call = mcalls.mcall[j];
                    if (call.to == address(0)) {
                        continue;
                    }
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

                    (bool success, bytes memory res) = _executePackedCall(
                        wallet.addr,
                        call.to,
                        call.flags,
                        call.gasLimit,
                        localMessageHash,
                        call.value,
                        call.data
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
            s_nonce_group[ng] = _nextNonce(nonce, maxNonce);
            emit BatchTransfered(7, block.number, maxNonce);
        }
    }

    function uid() external view returns (bytes32) {
        return s_uid;
    }

    function activator() external view returns (address) {
        return s_activator;
    }

    /** @notice _calcRefund - calculates the amount of refund to give based on the following input params:
        @param debt(uint256)
        @param gas(uint256)
        @param constGas(uint256)
        @param gasPriceLimit(uint256)
        @return uint88
    */
    function _calcRefund(
        uint256 debt,
        uint256 gas,
        uint256 constGas,
        uint256 gasPriceLimit
    ) private view returns (uint88) {
        return (
            debt != 0
                ? uint88(
                    (tx.gasprice + (gasPriceLimit - tx.gasprice) / 2) *
                        (((gas - gasleft()) * 110) / 100 + constGas + 5000)
                )
                : uint88(
                    (tx.gasprice + (gasPriceLimit - tx.gasprice) / 2) *
                        (((gas - gasleft()) * 110) / 100 + constGas + 8000)
                )
        );
    }

    function _encodeTransfer(Transfer memory call)
        private
        pure
        returns (bytes32 messageHash)
    {
        return
            keccak256(
                abi.encode(
                    BATCH_TRANSFER_TYPEHASH,
                    call.token,
                    call.tokenEnsHash,
                    call.to,
                    call.toEnsHash,
                    call.value,
                    uint64(call.sessionId >> NONCE_BIT), // group + nonce
                    uint40(call.sessionId >> AFTER_TS_BIT),
                    uint40(call.sessionId >> BEFORE_TS_BIT),
                    uint32(call.sessionId >> GAS_LIMIT_BIT),
                    uint64(call.sessionId >> GAS_PRICE_LIMIT_BIT),
                    bool(call.sessionId & FLAG_PAYMENT != 0)
                )
            );
    }

    function _calcCallTransactionHash(Call memory call)
        private
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encode(
                    BATCH_CALL_TRANSACTION_TYPEHASH,
                    call.to,
                    call.ensHash,
                    call.value,
                    uint64(call.sessionId >> NONCE_BIT), // group + nonce
                    uint40(call.sessionId >> AFTER_TS_BIT),
                    uint40(call.sessionId >> BEFORE_TS_BIT),
                    uint32(call.sessionId >> GAS_LIMIT_BIT),
                    uint64(call.sessionId >> GAS_PRICE_LIMIT_BIT),
                    bool(call.sessionId & FLAG_STATICCALL != 0),
                    bool(call.sessionId & FLAG_PAYMENT != 0),
                    call.functionSignature
                )
            );
    }

    function _encodeCall(Call memory call)
        private
        view
        returns (bytes32 messageHash, address to)
    {
        to = _ensToAddress(call.ensHash, call.to);

        messageHash = call.functionSignature !=
            0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470
            ? keccak256(
                abi.encode(
                    call.typeHash,
                    _calcCallTransactionHash(call),
                    call.data
                )
            )
            : keccak256(
                abi.encode(call.typeHash, _calcCallTransactionHash(call))
            );
    }

    function _calcMultiSigTransactionHash(MSCall memory call)
        private
        pure
        returns (bytes32)
    {
        uint16 flags = call.flags;

        return
            keccak256(
                abi.encode(
                    BATCH_MULTI_SIG_CALL_TRANSACTION_TYPEHASH,
                    call.signer,
                    call.to,
                    call.ensHash,
                    call.value,
                    call.gasLimit,
                    flags & FLAG_STATICCALL,
                    flags & ON_FAIL_CONTINUE,
                    flags & ON_FAIL_STOP,
                    flags & ON_SUCCESS_STOP,
                    flags & ON_SUCCESS_REVERT,
                    call.functionSignature
                )
            );
    }

    function _checkSessionIdLimits(
        uint256 i,
        uint256 sessionId,
        uint256 nonce,
        uint256 maxNonce
    ) private view {
        if (i == 0) {
            require(
                sessionId >> NONCE_BIT >= nonce >> NONCE_BIT,
                "Factory: group+nonce too low"
            );
        } else {
            require(
                maxNonce >> NONCE_BIT < sessionId >> NONCE_BIT,
                "Factory: should be ordered"
            );
        }
        require(
            tx.gasprice <= uint64(sessionId >> GAS_PRICE_LIMIT_BIT),
            "Factory: gas price too high"
        );
        require(
            block.timestamp > uint40(sessionId >> AFTER_TS_BIT),
            "Factory: too early"
        );
        require(
            block.timestamp < uint40(sessionId >> BEFORE_TS_BIT),
            "Factory: too late"
        );
    }

    function _nextNonce(uint256 nonce, uint256 maxNonce)
        private
        pure
        returns (uint256)
    {
        require(
            (maxNonce < nonce + (1 << MAX_NONCE_JUMP_BIT)) &&
                (uint40(maxNonce >> NONCE_BIT) >= uint40(nonce >> NONCE_BIT)),
            "Factory: group+nonce too high"
        );
        return
            (maxNonce &
                0x000000ffffffffff000000000000000000000000000000000000000000000000) +
            (1 << NONCE_BIT);
    }
}
