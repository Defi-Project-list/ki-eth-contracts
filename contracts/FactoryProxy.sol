// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v2;

// import "openzeppelin-solidity/contracts/utils/cryptography/SignatureChecker.sol";
// import "openzeppelin-solidity/contracts/utils/cryptography/ECDSA.sol";
import "./FactoryStorage.sol";
// import "./Factory.sol";

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

struct PTransfer {
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
    bytes32 limitsTypeHash;
    uint256 sessionId;
    address signer;
    uint8 v;
    MCall[] mcall;
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
    bytes32 limitsTypeHash;
    uint256 sessionId;
    MSCall[] mcall;
    Signature[] signatures;
  }

contract FactoryProxy is FactoryStorage {

    uint8 public constant VERSION_NUMBER = 0x1;
    
    string public constant NAME = "Kirobo OCW Manager";
    
    string public constant VERSION = "1";

    bytes32 public constant TRANSFER_TYPEHASH = 0xf728cfc064674dacd2ced2a03acd588dfd299d5e4716726c6d5ec364d16406eb;

    bytes32 public constant BATCH_TRANSFER_TYPEHASH = keccak256(
        "BatchTransfer(address token_address,string token_ens,address to,string to_ens,uint256 value,uint64 nonce,uint40 valid_from,uint40 expires_at,uint32 gas_limit,uint64 gas_price_limit,bool ordered,bool refund)"
    );

    bytes32 public constant BATCH_CALL_TRANSACTION_TYPEHASH = keccak256(
        "Transaction(address call_address,string call_ens,uint256 eth_value,uint64 nonce,uint40 valid_from,uint40 expires_at,uint32 gas_limit,uint64 gas_price_limit,bool view_only,bool ordered,bool refund)"
    );

    bytes32 public constant BATCH_TRANSFER_PACKED_TYPEHASH = keccak256(
        "batchTransferPacked()"
    );

    // bytes4(keccak256("sendEther(address payable,uint256)"));
    bytes4 public constant TRANSFER_SELECTOR = 0xc61f08fd;

    event ErrorHandled(bytes reason);

    constructor(
        address owner1,
        address owner2,
        address owner3,
        ENS ens
    ) FactoryStorage(owner1, owner2, owner3) {
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
        // proxy = address(this);
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

    function setTarget(address target) external multiSig2of3(0) {
        require(s_frozen != true, "frozen");
        require(target != address(0), "no target");
        s_target = target;
    }

    function freezeTarget() external multiSig2of3(0) {
        s_frozen = true;
    }

    function setLocalEns(string calldata ens, address dest) external {
        s_local_ens[keccak256(abi.encodePacked("@",ens))] = dest;
    }

    // Batch Transfers: ETH & ERC20 Tokens
    function batchTransfer(Transfer[] calldata tr, uint24 nonceGroup) external {
      unchecked {
        require(msg.sender == s_activator, "Wallet: sender not allowed");
        uint256 nonce = s_nonce_group[nonceGroup] + (uint256(nonceGroup) << 232);
        uint256 maxNonce = 0;
        uint256 length = tr.length;
        uint256 constGas = (21000 + msg.data.length * 8) / length;
        for(uint256 i = 0; i < length; i++) {
            uint256 gas = gasleft();
            Transfer calldata call = tr[i];
            address to = _ensToAddress(call.toEnsHash, call.to);
            address token = _ensToAddress(call.tokenEnsHash, call.token);
            uint256 sessionId = call.sessionId;
            uint256 gasLimit = uint32(sessionId >> 80);

            if (i == 0) {
              require(sessionId >> 192 >= nonce >> 192, "Factory: group+nonce too low");
            } else {
              if (sessionId & FLAG_ORDERED > 0) { // ordered
                  require(uint40(maxNonce >> 192) < uint40(sessionId >> 192), "Factory: should be ordered");
              }
            }

            if (maxNonce < sessionId) {
                maxNonce = sessionId;
            }

            require(tx.gasprice <= uint64(sessionId >> 16) /*gasPriceLimit*/, "Factory: gas price too high");
            require(block.timestamp > uint40(sessionId >> 152) /*afterTS*/, "Factory: too early");
            require(block.timestamp < uint32(sessionId >> 112) /*beforeTS*/, "Factory: too late");

            bytes32 message = _encodeTransfer(call);

            bytes32 messageHash = _messageToRecover(
                message,
                sessionId & FLAG_EIP712 > 0
            );

            Wallet storage wallet = _getWalletFromMessage(call.signer, messageHash, uint8(sessionId) /*v*/, call.r, call.s);

            require(wallet.owner == true, "Factory: singer is not owner");

            (bool success, bytes memory res) = call.token == address(0) ?
                wallet.addr.call{gas: gasLimit==0 || gasLimit > gasleft() ? gasleft() : gasLimit}(abi.encodeWithSignature("transferEth(address,uint256)", to, call.value)):
                wallet.addr.call{gas: gasLimit==0 || gasLimit > gasleft() ? gasleft() : gasLimit}(abi.encodeWithSignature("transferERC20(address,address,uint256)", token, to, call.value));
            if (!success) {
                revert(_getRevertMsg(res));
            }

            if (sessionId & FLAG_PAYMENT > 0) {
                wallet.debt = _calcRefund(wallet.debt, gas, constGas + 12000, uint64(sessionId >> 16), sessionId & FLAG_PAYMENT);
                // wallet.debt = uint88(/*(tx.gasprice + (gasPriceLimit - tx.gasprice) / 2) * */ (gas - gasleft() + 16000 + (24000/length)));
            }
        }
        require(maxNonce < nonce + (1 << 216), "Factory: gourp+nonce too high");
        s_nonce_group[nonceGroup] = (maxNonce & 0x000000ffffffffff000000000000000000000000000000000000000000000000) + (1 << 192);
      }
    }

    // Batch Transfers: ETH & ERC20 Tokens
    function batchTransferPacked(PTransfer[] calldata tr, uint24 nonceGroup, bytes32 typeHash) external {
      unchecked {
        require(msg.sender == s_activator, "Wallet: sender not allowed");
        uint256 nonce = s_nonce_group[nonceGroup] + (uint256(nonceGroup) << 232);
        uint256 maxNonce = 0;
        uint256 length = tr.length;
        uint256 constGas = (21000 + msg.data.length * 8) / length;
        for(uint256 i = 0; i < length; i++) {
            uint256 gas = gasleft();
            PTransfer calldata call = tr[i];
            address to = call.to;
            uint256 value = call.value;
            address token = call.token;
            uint256 sessionId = call.sessionId;
            uint256 gasLimit = uint32(sessionId >> 80);

            if (i == 0) {
              require(sessionId >> 192 >= nonce >> 192, "Factory: group+nonce too low");
            } else {
              if (sessionId & FLAG_ORDERED > 0) { // ordered
                  require(uint40(maxNonce >> 192) < uint40(sessionId >> 192), "Factory: should be ordered");
              }
            }

            if (maxNonce < sessionId) {
                maxNonce = sessionId;
            }

            require(tx.gasprice <= uint64(sessionId >> 16) /*gasPriceLimit*/, "Factory: gas price too high");
            require(block.timestamp > uint40(sessionId >> 152) /*afterTS*/, "Factory: too early");
            require(block.timestamp < uint32(sessionId >> 112) /*beforeTS*/, "Factory: too late");

            bytes32 messageHash = _messageToRecover(
                keccak256(abi.encode(
                    BATCH_TRANSFER_PACKED_TYPEHASH,
                    token,
                    to,
                    value,
                    sessionId >> 8
                )),
                sessionId & FLAG_EIP712 > 0
            );

            Wallet storage wallet = _getWalletFromMessage(call.signer, messageHash, uint8(sessionId) /*v*/, call.r, call.s);

            require(wallet.owner == true, "Factory: singer is not owner");

            (bool success, bytes memory res) = token == address(0) ?
                wallet.addr.call{gas: gasLimit==0 || gasLimit > gasleft() ? gasleft() : gasLimit}(abi.encodeWithSignature("transferEth(address,uint256)", to, value)):
                wallet.addr.call{gas: gasLimit==0 || gasLimit > gasleft() ? gasleft() : gasLimit}(abi.encodeWithSignature("transferERC20(address,address,uint256)", token, to, value));
            if (!success) {
                revert(_getRevertMsg(res));
            }

            if (sessionId & FLAG_PAYMENT > 0) {
                wallet.debt = _calcRefund(wallet.debt, gas, constGas + 12000, uint64(sessionId >> 16), sessionId & FLAG_PAYMENT);
                // wallet.debt = uint88(/*(tx.gasprice + (gasPriceLimit - tx.gasprice) / 2) * */ (gas - gasleft() + 16000 + (24000/length)));
            }
        }
        require(maxNonce < nonce + (1 << 216), "Factory: gourp+nonce too high");
        s_nonce_group[nonceGroup] = (maxNonce & 0x000000ffffffffff000000000000000000000000000000000000000000000000) + (1 << 192);
      }
    }

    // Batch Call: External Contract Functions
    function batchCall(Call[] calldata tr, uint256 nonceGroup) external {
      unchecked {
        require(msg.sender == s_activator, "Wallet: sender not allowed");
        uint256 nonce = s_nonce_group[nonceGroup] + (nonceGroup << 232);
        uint256 maxNonce = 0;
        uint256 length = tr.length;
        uint256 constGas = (21000 + msg.data.length * 16) / length;
        for(uint256 i = 0; i < length; i++) {
            uint256 gas = gasleft();

            Call calldata call = tr[i];
            uint256 sessionId = call.sessionId;
            uint256 gasLimit  = uint32(sessionId >> 80);

            if (i == 0) {
              require(sessionId >> 192 >= nonce >> 192, "Factory: group+nonce too low");
            } else {
              if (sessionId & FLAG_ORDERED > 0) { // ordered
                  require(uint40(maxNonce >> 192) < uint40(sessionId >> 192), "Factory: should be ordered");
              }
            }

            if (maxNonce < sessionId) {
                maxNonce = sessionId;
            }

            require(tx.gasprice <= uint64(sessionId >> 16) /*gasPriceLimit*/, "Factory: gas price too high");
            require(block.timestamp > uint40(sessionId >> 152) /*afterTS*/, "Factory: too early");
            require(block.timestamp < uint40(sessionId >> 112) /*beforeTS*/, "Factory: too late");

            (bytes32 messageHash, address to) = _encodeCall(call);

            Wallet storage wallet = _getWalletFromMessage(
                call.signer,
                _messageToRecover(
                    messageHash,
                    sessionId & FLAG_EIP712 > 0
                ), 
                uint8(sessionId) /*v*/,
                call.r,
                call.s
            );
            // return;
            require(wallet.owner == true, "Factory: singer is not owner");

            (bool success, bytes memory res) = sessionId & FLAG_STATICCALL > 0 ?
                wallet.addr.call{gas: gasLimit==0 || gasLimit > gasleft() ? gasleft() : gasLimit}(
                  abi.encodeWithSignature("staticcall(address,bytes)",
                      to,
                      abi.encodePacked(bytes4(call.functionSignature), call.data))):
                wallet.addr.call{gas: gasLimit==0 || gasLimit > gasleft() ? gasleft() : gasLimit }(
                  abi.encodeWithSignature("call(address,uint256,bytes)", to, call.value, abi.encodePacked(
                    bytes4(call.functionSignature), call.data)));
            if (!success) {
                revert(_getRevertMsg(res));
            }
            uint256 payment = sessionId & FLAG_PAYMENT;
            if (payment > 0) {
              wallet.debt = _calcRefund(wallet.debt, gas, constGas, uint64(sessionId >> 16), sessionId & FLAG_PAYMENT);
                // if (payment == 0xf000) {
                //   wallet.debt = uint88(/*(tx.gasprice + (gasPriceLimit - tx.gasprice) / 2) * */ (gas - gasleft() + 16000 + (32000/length))*110/100);
                // } else {
                //   wallet.debt = uint88((tx.gasprice + (uint64(sessionId >> 16) /*gasPriceLimit*/ - tx.gasprice) / 2) * (gas - gasleft() + 16000 + (32000/length))*110/100);
                // }
            }
        }
        require(maxNonce < nonce + (1 << 216), "Factory: group+nonce too high");
        s_nonce_group[nonceGroup] = (maxNonce & 0x000000ffffffffff000000000000000000000000000000000000000000000000) + (1 << 192);
      }
    }

    // Batch Call: Multi External Contract Functions
    function batchMultiCall(MCalls[] calldata tr, uint256 nonceGroup) external {
      unchecked {

        require(msg.sender == s_activator, "Wallet: sender not allowed");
        uint256 nonce = s_nonce_group[nonceGroup] + (uint256(nonceGroup) << 232);
        uint256 maxNonce = 0;
        uint256 trLength = tr.length;
        uint256 constGas = (21000 + msg.data.length * 8) / trLength;
        // emit ErrorHandled(abi.encode(gasleft(), msg.data.length, constGas));
        // return;
        for(uint256 i = 0; i < trLength; i++) {
            uint256 gas = gasleft();
            MCalls calldata mcalls = tr[i];
            uint256 sessionId = mcalls.sessionId;
            uint256 afterTS = uint40(sessionId >> 152);
            uint256 beforeTS = uint40(sessionId >> 112);
            uint256 gasPriceLimit = uint64(sessionId >> 16);
            bool refund = sessionId & FLAG_PAYMENT > 0;
            bool ordered = sessionId & FLAG_ORDERED > 0;
            bytes memory msg2 = abi.encode(mcalls.typeHash, keccak256(abi.encode(mcalls.limitsTypeHash, uint64(sessionId >> 192), ordered, refund, afterTS, beforeTS, gasPriceLimit)));

            if (i == 0) {
              require(sessionId >> 192 >= nonce >> 192, "Factory: group+nonce too low");
            } else {
              if (sessionId & FLAG_ORDERED > 0) {
                  require(uint40(maxNonce >> 192) < uint40(sessionId >> 192), "Factory: should be ordered");
              }
            }

            if (maxNonce < sessionId) {
                maxNonce = sessionId;
            }

            require(tx.gasprice <= gasPriceLimit, "Factory: gas price too high");
            require(block.timestamp > afterTS, "Factory: too early");
            require(block.timestamp < beforeTS, "Factory: too late");
            uint256 length = mcalls.mcall.length;
            // address[] memory toList = new address[](length);
            for(uint256 j = 0; j < length; j++) {
                MCall calldata call = mcalls.mcall[j];
                bytes32 functionSignature = call.functionSignature;
                // (bytes32 messageHash, address to) = _encodeMCall2(call);
                uint16 flags = call.flags;
                msg2 = abi.encodePacked(
                    msg2,
                    // messageHash
                    functionSignature != 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 ?
                        keccak256(abi.encode(
                            call.typeHash,
                            call.to,
                            call.ensHash,
                            call.value,
                            call.gasLimit,
                            flags & FLAG_STATICCALL,
                            flags & ON_FAIL_CONTINUE,
                            flags & ON_FAIL_STOP,
                            flags & ON_SUCCESS_STOP,
                            flags & ON_SUCCESS_REVERT,
                            call.functionSignature,
                            call.data
                        )):
                        keccak256(abi.encode(
                            call.typeHash,
                            call.to,
                            call.ensHash,
                            call.value,
                            call.gasLimit,
                            flags & FLAG_STATICCALL,
                            flags & ON_FAIL_CONTINUE,
                            flags & ON_FAIL_STOP,
                            flags & ON_SUCCESS_STOP,
                            flags & ON_SUCCESS_REVERT
                        ))
                );
                // toList[j] = to;
            }

            // emit ErrorHandled(abi.encodePacked(mcalls.r, mcalls.s, mcalls.v));
            // emit ErrorHandled(abi.encodePacked(msg2));
            // return;

            Wallet storage wallet = _getWalletFromMessage(
                mcalls.signer,
                _messageToRecover(
                    keccak256(msg2),
                    sessionId & FLAG_EIP712 > 0
                ), 
                mcalls.v,
                mcalls.r,
                mcalls.s
            );

            require(wallet.owner == true, "Factory: singer is not owner");

            // uint256 length = mcalls.mcall.length;
            for(uint256 j = 0; j < length; j++) {
                MCall calldata call = mcalls.mcall[j];
                uint32 gasLimit = call.gasLimit;
                uint16 flags = call.flags;
                address to = _ensToAddress(call.ensHash, call.to); // toList[j];
                bytes32 functionSignature = call.functionSignature;

                (bool success, bytes memory res) = flags & FLAG_STATICCALL > 0 ?
                    wallet.addr.call{gas: gasLimit==0 || gasLimit > gasleft() ? gasleft() : gasLimit}(
                        abi.encodeWithSignature(
                            "staticcall(address,bytes)",
                            to,
                            abi.encodePacked(bytes4(functionSignature), call.data)
                        )
                    ) :
                    wallet.addr.call{gas: gasLimit==0 || gasLimit > gasleft() ? gasleft() : gasLimit}(
                        abi.encodeWithSignature(
                            "call(address,uint256,bytes)",
                            to,
                            call.value,
                            functionSignature == 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 ? 
                                bytes('') : 
                                abi.encodePacked(bytes4(functionSignature), call.data)
                        )
                    );
                if (!success) {
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
                wallet.debt = _calcRefund(wallet.debt, gas, constGas, gasPriceLimit, sessionId & FLAG_PAYMENT);
                //  (wallet.debt > 0  ? 
                //   uint88(/*(tx.gasprice + (gasPriceLimit - tx.gasprice) / 2) * */ (gas - gasleft() + constGas + 5000) * 110 / 100):
                //   uint88(/*(tx.gasprice + (gasPriceLimit - tx.gasprice) / 2) * */ (gas - gasleft() + constGas + 22100)) * 110 / 100);
                  // // wallet.debt = uint88(/*(tx.gasprice + (gasPriceLimit - tx.gasprice) / 2) * */ (gas - gasleft() + 18000 + (30000/trLength))*110/100);
                  // wallet.debt = uint88(/*(tx.gasprice + (gasPriceLimit - tx.gasprice) / 2) * */ (gas - gasleft() + 16000 + (32000/trLength))*110/100);
            }
        }
        require(maxNonce < nonce + (1 << 216), "Factory: gourp+nonce too high");
        s_nonce_group[nonceGroup] = (maxNonce & 0x000000ffffffffff000000000000000000000000000000000000000000000000) + (1 << 192);
      }
    }

    // Batch Call: Multi Signature, Multi External Contract Functions
    function batchMultiSigCall(MSCalls[] calldata tr, uint256 nonceGroup) external {
        unchecked {
            require(msg.sender == s_activator, "Wallet: sender not allowed");
            uint256 nonce = s_nonce_group[nonceGroup] + (uint256(nonceGroup) << 232);
            uint256 maxNonce = 0;
            uint256 trLength = tr.length;
            for(uint256 i = 0; i < trLength; i++) {
                uint256 gas = gasleft();
                MSCalls calldata mcalls = tr[i];
                uint256 sessionId = mcalls.sessionId;
                // uint256 afterTS = uint40(sessionId >> 152);
                // uint256 beforeTS  = uint40(sessionId >> 112);
                // uint256 gasPriceLimit  = uint64(sessionId >> 16);
                // bool refund = sessionId & FLAG_PAYMENT > 0;
                // bool ordered = sessionId & FLAG_ORDERED > 0;
                bytes memory msg2 = abi.encode(
                    mcalls.typeHash,
                    keccak256(abi.encode(
                        mcalls.limitsTypeHash,
                        uint64(sessionId >> 192),
                        sessionId & FLAG_ORDERED > 0, // ordered
                        sessionId & FLAG_PAYMENT > 0, // refund
                        uint40(sessionId >> 152), // afterTS
                        uint40(sessionId >> 112), // beforeTS
                        uint64(sessionId >> 16) // gasPriceLimit
                    ))
                );

                if (i == 0) {
                require(sessionId >> 192 >= nonce >> 192, "Factory: group+nonce too low");
                } else {
                if (sessionId & FLAG_ORDERED > 0) {
                    require(uint40(maxNonce >> 192) < uint40(sessionId >> 192), "Factory: should be ordered");
                }
                }

                if (maxNonce < sessionId) {
                    maxNonce = sessionId;
                }

                require(tx.gasprice <= uint64(sessionId >> 16) /*gasPriceLimit*/, "Factory: gas price too high");
                require(block.timestamp > uint40(sessionId >> 152) /*afterTS*/, "Factory: too early");
                require(block.timestamp < uint40(sessionId >> 112) /*beforeTS*/, "Factory: too late");
                uint256 length = mcalls.mcall.length;
                // address[] memory toList = new address[](length);

                for(uint256 j = 0; j < length; j++) {
                    MSCall calldata call = mcalls.mcall[j];
                    // bytes32 functionSignature = call.functionSignature;
                    // (bytes32 messageHash, address to) = _encodeMCall2(call);
                    uint16 flags = call.flags;
                    msg2 = abi.encodePacked(
                        msg2,
                        // messageHash
                        call.functionSignature != 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 ?
                            keccak256(abi.encode(
                                call.typeHash,
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
                                call.functionSignature,
                                call.data
                            )):
                        call.to != address(0) ?                            
                            keccak256(abi.encode(
                                call.typeHash,
                                call.signer,
                                call.to,
                                call.ensHash,
                                call.value,
                                call.gasLimit,
                                flags & FLAG_STATICCALL,
                                flags & ON_FAIL_CONTINUE,
                                flags & ON_FAIL_STOP,
                                flags & ON_SUCCESS_STOP,
                                flags & ON_SUCCESS_REVERT
                            )):
                            keccak256(abi.encode(
                                call.typeHash,
                                call.signer
                            ))

                    );
                    // toList[j] = to;
                }

                // emit ErrorHandled(abi.encodePacked(mcalls.r, mcalls.s, mcalls.v));
                // emit ErrorHandled(abi.encodePacked(msg2));
                // return;

                bytes32 messageToRecover = _messageToRecover(
                    keccak256(msg2),
                    sessionId & FLAG_EIP712 > 0
                );

                address[] memory signers = new address[](length);

                for(uint256 s = 0; s < mcalls.signatures.length; ++s) {
                    Signature calldata signature = mcalls.signatures[s];
                    for(uint256 j = 0; j < length; j++) {
                        MSCall calldata call = mcalls.mcall[j];
                        address signer = _addressFromMessageAndSignature(
                            messageToRecover,
                            signature.v,
                            signature.r,
                            signature.s
                        );
                        if (signer == call.signer) { //  && signers[j] == address(0)) {
                            signers[j] = signer;
                        }
                    }
                }

            //  emit ErrorHandled(abi.encodePacked(signers));
            //  return;
            
            for(uint256 j = 0; j < length; j++) {
                    // address signer = signers[j];
                    require(signers[j] != address(0), "Factory: signer missing");
                    MSCall calldata call = mcalls.mcall[j];
                    if (call.to == address(0)) {
                        continue;
                    }
                    Wallet storage wallet = s_accounts_wallet[signers[j]];
                    require(wallet.owner == true, "Factory: signer is not owner");
                    // uint32 gasLimit = call.gasLimit;
                    // uint16 flags = call.flags;
                    address to = _ensToAddress(call.ensHash, call.to); // toList[j];
                    // bytes32 functionSignature = call.functionSignature;

                    (bool success, bytes memory res) = call.flags & FLAG_STATICCALL > 0 ?
                        wallet.addr.call{gas: call.gasLimit==0 || call.gasLimit > gasleft() ? gasleft() : call.gasLimit}(
                            abi.encodeWithSignature(
                                "staticcall(address,bytes)",
                                to,
                                abi.encodePacked(bytes4(call.functionSignature), call.data)
                            )
                        ) :
                        wallet.addr.call{gas: call.gasLimit==0 || call.gasLimit > gasleft() ? gasleft() : call.gasLimit}(
                            abi.encodeWithSignature(
                                "call(address,uint256,bytes)",
                                to,
                                call.value,
                                call.functionSignature == 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 ? 
                                    bytes('') : 
                                    abi.encodePacked(bytes4(call.functionSignature), call.data)
                            )
                        );
                    if (!success) {
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
                    if (sessionId & FLAG_PAYMENT > 0) {
                        // wallet.debt = uint88(/*(tx.gasprice + (gasPriceLimit - tx.gasprice) / 2) * */ (gas - gasleft() + 18000 + (30000/trLength))*110/100);
                        wallet.debt = uint88((tx.gasprice + (uint64(sessionId >> 16) - tx.gasprice) / 2) * (gas - gasleft() + 18000 + (30000/trLength))*110/100);
                        // wallet.debt = uint88(/*(tx.gasprice + (gasPriceLimit - tx.gasprice) / 2) * */ (gas - gasleft() + 16000 + (32000/trLength))*110/100);
                    }
                }
            }
            require(maxNonce < nonce + (1 << 216), "Factory: gourp+nonce too high");
            s_nonce_group[nonceGroup] = (maxNonce & 0x000000ffffffffff000000000000000000000000000000000000000000000000) + (1 << 192);
        }
    }

    function uid() view external returns (bytes32) {
        return s_uid;
    }

    function operator() external view returns (address) {
      return s_operator;
    }

    function activator() external view returns (address) {
      return s_activator;
    }

    function managers() external view returns (address, address) {
      return (s_operator, s_activator);
    }

    function _calcRefund(uint256 debt, uint256 gas, uint256 constGas, uint256 gasPriceLimit, uint256 payment) private view returns (uint88) {
        return uint88((gas - gasleft()) * 110 / 100 + constGas + 8000);
        // return (debt > 0  ? 
        //           uint88((tx.gasprice + (gasPriceLimit - tx.gasprice) / 2) * ((gas - gasleft()) * 110 / 100 + constGas + 5000)):
        //           uint88((tx.gasprice + (gasPriceLimit - tx.gasprice) / 2) * ((gas - gasleft()) * 110 / 100 + constGas + 5000)));
        //           // uint88(/*(tx.gasprice + (gasPriceLimit - tx.gasprice) / 2) * */ (gas - gasleft() + constGas + 15000) /*22100))*/ * 110 / 100 ));
    }

    function _encodeTransfer(Transfer memory call) private view returns (bytes32 messageHash) {
        return keccak256(abi.encode(
                BATCH_TRANSFER_TYPEHASH,
                call.token,
                call.tokenEnsHash,
                call.to,
                call.toEnsHash,
                call.value,
                uint64(call.sessionId >> 192), // group + nonce
                uint40(call.sessionId >> 152), // afterTS,
                uint40(call.sessionId >> 112), // beforeTS
                uint32(call.sessionId >> 80), // gasLimit
                uint64(call.sessionId >> 16), // gasPriceLimit,
                bool(call.sessionId & FLAG_ORDERED > 0), // ordered
                bool(call.sessionId & FLAG_PAYMENT > 0) // refund
            ));
    }

    function _calcCallTransactionHash(Call memory call) private pure returns (bytes32) {
        return keccak256(abi.encode(
                BATCH_CALL_TRANSACTION_TYPEHASH,
                call.to,
                call.ensHash,
                call.value,
                uint64(call.sessionId >> 192), // group + nonce
                uint40(call.sessionId >> 152), // afterTS,
                uint40(call.sessionId >> 112), // beforeTS
                uint32(call.sessionId >> 80), // gasLimit
                uint64(call.sessionId >> 16), // gasPriceLimit,
                bool(call.sessionId & FLAG_STATICCALL > 0), // staticcall
                bool(call.sessionId & FLAG_ORDERED > 0), // ordered
                bool(call.sessionId & FLAG_PAYMENT > 0) // refund
        ));
    }

    function _encodeCall(Call memory call) private view returns (bytes32 messageHash, address to) {
        to = _ensToAddress(call.ensHash, call.to);
 
        // emit ErrorHandled(abi.encode(BATCH_CALL_TRANSACTION_TYPEHASH));
        // emit ErrorHandled(abi.encode(
        //         call.typeHash,
        //         _calcCallTransactionHash(call),
        //         call.functionSignature,
        //         call.data
        //     ));

        messageHash = call.functionSignature != 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 ?
            keccak256(abi.encode(
                call.typeHash,
                _calcCallTransactionHash(call),
                call.functionSignature,
                call.data
            )):
            keccak256(abi.encode(
                call.typeHash,
                _calcCallTransactionHash(call)
            ));
    }

    function _encodeMCall(MCall memory call) private view returns (bytes32, address) {
        return (keccak256(abi.encode(
                  call.typeHash,
                  call.to,
                  call.ensHash,
                  call.value,
                  call.gasLimit,
                  call.functionSignature,
                  call.data
          )),
          _ensToAddress(call.ensHash, call.to));
    }

}
