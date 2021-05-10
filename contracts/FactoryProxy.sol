// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v2;

import "openzeppelin-solidity/contracts/utils/cryptography/SignatureChecker.sol";
import "openzeppelin-solidity/contracts/utils/cryptography/ECDSA.sol";
import "./FactoryStorage.sol";
// import "./Factory.sol";


contract FactoryProxy is FactoryStorage {

    using SignatureChecker for address;
    using ECDSA for bytes32;

    uint8 public constant VERSION_NUMBER = 0x1;
    string public constant NAME = "Kirobo OCW Manager";
    string public constant VERSION = "1";

    function uid() view external returns (bytes32) {
        return s_uid;
    }

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

    function _resolve(bytes32 node) internal view returns(address result) {
        require(address(s_ens) != address(0), "Factory: ens not defined");
        Resolver resolver = s_ens.resolver(node);
        require(address(resolver) != address(0), "Factory: resolver not found");
        result = resolver.addr(node);
        require(result != address(0), "Factory: ens address not found");
    }
    
    uint256 private constant FLAG_EIP712  = 0x0100;
    uint256 private constant FLAG_ORDERED = 0x0200;
    uint256 private constant FLAG_STATICCALL = 0x0400;
    uint256 private constant FLAG_PAYMENT = 0xf000;
    uint256 private constant FLAG_FLOW = 0x00ff;

    uint256 private constant ON_FAIL_STOP = 0x01;
    uint256 private constant ON_FAIL_CONTINUE = 0x02;
    uint256 private constant ON_SUCCESS_STOP = 0x10;
    uint256 private constant ON_SUCCESS_REVERT = 0x20;
    
    function setTarget(address target) public multiSig2of3(0) {
        require(s_frozen != true, "frozen");
        require(target != address(0), "no target");
        s_target = target;
    }

    function freezeTarget() public multiSig2of3(0) {
        s_frozen = true;
    }

    function operator() public view returns (address) {
      return s_operator;
    }

    function activator() public view returns (address) {
      return s_activator;
    }

    function managers() public view returns (address, address) {
      return (s_operator, s_activator);
    }


    event ErrorHandled(bytes reason);

    // keccak256("acceptTokens(address recipient,uint256 value,bytes32 secretHash)");
    bytes32 public constant TRANSFER_TYPEHASH = 0xf728cfc064674dacd2ced2a03acd588dfd299d5e4716726c6d5ec364d16406eb;


    bytes32 public constant BATCH_TRANSFER_TYPEHASH = keccak256(
      "batchTransfer(address token_address,address recipient,uint256 token_amount,uint256 sessionId,uint40 after,uint40 before,uint32 gasLimit,uint64 gasPriceLimit)"
    );

    bytes32 public constant BATCH_CALL_TYPEHASH = keccak256(
      "batchCall(address token,address to,uint256 value,uint256 sessionId,bytes data)"
    );

    // bytes4(keccak256("sendEther(address payable,uint256)"));
    bytes4 public constant TRANSFER_SELECTOR = 0xc61f08fd;

    struct Transfer {
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
        address to;
        uint256 value;
        uint256 sessionId;
        address signer;
        bytes data;
    }

    struct Call2 {
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
        address to;
        uint256 value;
        uint16 flags;
        uint32 gasLimit;
        bytes4 selector;
        bytes data;
     }

     struct MCalls {
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 sessionId;
        address signer;
        MCall[] mcall;
     }

     struct MCall2 {
        bytes32 typeHash;
        address to;
        uint256 value;
        uint16 flags;
        uint32 gasLimit;
        bytes4 selector;
        bytes data;
     }

     struct MCalls2 {
        uint8 v;
        bytes32 r;
        bytes32 s;
        bytes32 typeHash;
        uint256 sessionId;
        address signer;
        MCall2[] mcall;
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
        require(msg.sender == s_activator, "Wallet: sender not allowed");
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
            address wallet = s_accounts_wallet[signer].addr;
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

    function _getWalletFromMessage(address signer, bytes32 messageHash, uint8 v, bytes32 r, bytes32 s) private returns (Wallet storage) {
        if (signer == address(0)) {
            if (v != 0) {
               ErrorHandled(abi.encodePacked(messageHash.recover(
                    v,
                    r,
                    s
                )));
                return s_accounts_wallet[messageHash.recover(
                    v,
                    r,
                    s
                )];
            } else {
                return s_accounts_wallet[messageHash.recover(
                    27 + uint8(uint256(s) >> 255),
                    r,
                    s & 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
                )];
            }
        } else if (signer.isValidSignatureNow(messageHash, v!=0 ? abi.encodePacked(r, s, v): abi.encodePacked(r,s))) {
            return s_accounts_wallet[signer];
        }
        revert("Factory: wrong signer");
    }

    function batchTransfer(Transfer[] calldata tr, uint24 nonceGroup) public {
      unchecked {
        require(msg.sender == s_activator, "Wallet: sender not allowed");
        uint256 nonce = s_nonce_group[nonceGroup] + (uint256(nonceGroup) << 232);
        uint256 maxNonce = 0;
        uint256 length = tr.length;
        for(uint256 i = 0; i < length; i++) {
            uint256 gas = gasleft();
            Transfer calldata call = tr[i];
            address to = call.to;
            uint256 value = call.value;
            address token = call.token;
            uint256 sessionId = call.sessionId;
            uint256 afterTS = uint40(sessionId >> 152);
            uint256 beforeTS = uint40(sessionId >> 112);
            uint256 gasLimit = uint32(sessionId >> 80);
            uint256 gasPriceLimit = uint64(sessionId >> 16);

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

            require(tx.gasprice <= gasPriceLimit, "Factory: gas price too high");
            require(block.timestamp > afterTS, "Factory: too early");
            require(block.timestamp < beforeTS, "Factory: too late");

            bytes32 messageHash = _messageToRecover(
                keccak256(abi.encode(BATCH_TRANSFER_TYPEHASH, token, to, value, sessionId >> 8, afterTS, beforeTS, gasLimit, gasPriceLimit)),
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
                wallet.debt = uint88(/*(tx.gasprice + (gasPriceLimit - tx.gasprice) / 2) * */ (gas - gasleft() + 16000 + (24000/length)));
            }
        }
        require(maxNonce < nonce + (1 << 216), "Factory: gourp+nonce too high");
        s_nonce_group[nonceGroup] = (maxNonce & 0x000000ffffffffff000000000000000000000000000000000000000000000000) + (1 << 192);
      }
    }

    function _calcPayment(uint256 gas, uint256 length) private pure returns (uint88) {
        return uint88((gas + 16000 + (24000/length)));
    }

    function _selector(bytes calldata data) private pure returns (bytes4) {
        return data[0] | (bytes4(data[1]) >> 8) | (bytes4(data[2]) >> 16) | (bytes4(data[3]) >> 24);
    }

    function _ensToAddress(bytes32 ensHash, address expectedAddress) private returns (address result) {
        if (ensHash == 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 || ensHash == bytes32(0)) {
          return expectedAddress;
        }
        result = s_local_ens[ensHash];
        if (result == address(0)) {
          result = _resolve(ensHash);
        }
        if (expectedAddress != address(0)) {
            require(result == expectedAddress, "Factory: ens address mismatch");
        }
        require(result != address(0), "Factory: ens address not found");
    }

    function setLocalEns(string calldata ens, address dest) external {
        s_local_ens[keccak256(abi.encodePacked("@",ens))] = dest;
    }

    function _encodeCall2(Call2 memory call) private returns (bytes32, address) {
        return (keccak256(abi.encode(
                  call.typeHash,
                  call.to,
                  call.ensHash,
                  call.value,
                  // uint24(call.sessionId >> 232), // group
                  uint64(call.sessionId >> 192), // group + nonce
                  uint40(call.sessionId >> 152), // afterTS,
                  uint40(call.sessionId >> 112), // beforeTS
                  uint32(call.sessionId >> 80), // gasLimit
                  uint64(call.sessionId >> 16), // gasPriceLimit,
                  bool(call.sessionId & FLAG_STATICCALL > 0), // staticcall
                  bool(call.sessionId & FLAG_ORDERED > 0), // ordered
                  bool(call.sessionId & FLAG_PAYMENT > 0), // refund
                  call.functionSignature,
                  call.data
          )),
          _ensToAddress(call.ensHash, call.to));
    }

    function batchCall2(Call2[] calldata tr, uint256 nonceGroup) public {
      unchecked {
        require(msg.sender == s_activator, "Wallet: sender not allowed");
        uint256 nonce = s_nonce_group[nonceGroup] + (nonceGroup << 232);
        uint256 maxNonce = 0;
        uint256 length = tr.length;
        for(uint256 i = 0; i < length; i++) {
            uint256 gas = gasleft();

            Call2 calldata call = tr[i];
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

            (bytes32 messageHash, address to) = _encodeCall2(call);

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
                if (payment == 0xf000) {
                  wallet.debt = uint88(/*(tx.gasprice + (gasPriceLimit - tx.gasprice) / 2) * */ (gas - gasleft() + 16000 + (32000/length))*110/100);
                } else {
                  wallet.debt = uint88((tx.gasprice + (uint64(sessionId >> 16) /*gasPriceLimit*/ - tx.gasprice) / 2) * (gas - gasleft() + 16000 + (32000/length))*110/100);
                }
            }
        }
        require(maxNonce < nonce + (1 << 216), "Factory: group+nonce too high");
        s_nonce_group[nonceGroup] = (maxNonce & 0x000000ffffffffff000000000000000000000000000000000000000000000000) + (1 << 192);
      }
    }

    function batchCall(Call[] calldata tr, uint256 nonceGroup) public {
      unchecked {
        require(msg.sender == s_activator, "Wallet: sender not allowed");
        uint256 nonce = s_nonce_group[nonceGroup] + (nonceGroup << 232);
        uint256 maxNonce = 0;
        uint256 length = tr.length;
        for(uint256 i = 0; i < length; i++) {
            uint256 gas = gasleft();

            Call calldata call = tr[i];
            address to = call.to;
            uint256 value = call.value;
            uint256 sessionId = call.sessionId;
            uint256 gasLimit  = uint32(sessionId >> 80);
            uint256 gasPriceLimit  = uint64(sessionId >> 16);

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

            require(tx.gasprice <= gasPriceLimit, "Factory: gas price too high");
            require(block.timestamp > uint40(sessionId >> 152) /*afterTS*/, "Factory: too early");
            require(block.timestamp < uint40(sessionId >> 112) /*beforeTS*/, "Factory: too late");

            bytes32 messageHash = keccak256(abi.encode(BATCH_CALL_TYPEHASH, to, value, sessionId >> 8, call.data));

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
            
            require(wallet.owner == true, "Factory: singer is not owner");

            (bool success, bytes memory res) = sessionId & FLAG_STATICCALL > 0 ?
                wallet.addr.call{gas: gasLimit==0 || gasLimit > gasleft() ? gasleft() : gasLimit}(abi.encodeWithSignature("staticcall(address,bytes)", to, call.data)):
                wallet.addr.call{gas: gasLimit==0 || gasLimit > gasleft() ? gasleft() : gasLimit}(abi.encodeWithSignature("call(address,uint256,bytes)", to, value, call.data));
            if (!success) {
                revert(_getRevertMsg(res));
            }
            uint256 payment = sessionId & FLAG_PAYMENT;
            if (payment > 0) {
                if (payment == 0xf000) {
                  wallet.debt = uint88(/*(tx.gasprice + (gasPriceLimit - tx.gasprice) / 2) * */ (gas - gasleft() + 16000 + (32000/length))*110/100);
                } else {
                  wallet.debt = uint88((tx.gasprice + (gasPriceLimit - tx.gasprice) / 2) * (gas - gasleft() + 16000 + (32000/length))*110/100);
                }
            }
        }
        require(maxNonce < nonce + (1 << 216), "Factory: gourp+nonce too high");
        s_nonce_group[nonceGroup] = (maxNonce & 0x000000ffffffffff000000000000000000000000000000000000000000000000) + (1 << 192);
      }
    }

    function batchMultiCall(MCalls[] calldata tr, uint256 nonceGroup) public {
      unchecked {
        require(msg.sender == s_activator, "Wallet: sender not allowed");
        uint256 nonce = s_nonce_group[nonceGroup] + (uint256(nonceGroup) << 232);
        uint256 maxNonce = 0;
        uint256 trLength = tr.length;
        for(uint256 i = 0; i < trLength; i++) {
            uint256 gas = gasleft();
            MCalls calldata mcalls = tr[i];
            bytes memory msgPre = abi.encode(0x20, mcalls.mcall.length, 32*mcalls.mcall.length);
            bytes memory msg2;
            uint256 sessionId = mcalls.sessionId;
            uint256 afterTS = uint40(sessionId >> 152);
            uint256 beforeTS  = uint40(sessionId >> 112);
            uint256 gasPriceLimit  = uint64(sessionId >> 16);

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
            for(uint256 j = 0; j < length; j++) {
                MCall calldata call = mcalls.mcall[j];
                address to = call.to;
                msg2 = abi.encodePacked(msg2, abi.encode(call.typeHash, to, call.value, sessionId, afterTS, beforeTS, call.gasLimit, gasPriceLimit, call.selector, call.data));
                if (j < mcalls.mcall.length-1) {
                  msgPre = abi.encodePacked(msgPre, msg2.length + 32*mcalls.mcall.length);
                }
            }

            bytes32 messageHash = _messageToRecover(
                keccak256(abi.encodePacked(msgPre, msg2)),
                sessionId & FLAG_EIP712 > 0
            );
            
            // emit ErrorHandled(abi.encodePacked(msgPre, msg2));
            // return ;

            Wallet storage wallet = _getWalletFromMessage(mcalls.signer, messageHash, mcalls.v, mcalls.r, mcalls.s);
            require(wallet.owner == true, "Factory: singer is not owner");

            // uint256 length = mcalls.mcall.length;
            for(uint256 j = 0; j < length; j++) {
                MCall calldata call = mcalls.mcall[j];
                uint32 gasLimit = call.gasLimit;
                uint16 flags = call.flags;

                (bool success, bytes memory res) = call.flags & FLAG_STATICCALL > 0 ?
                    wallet.addr.call{gas: gasLimit==0 || gasLimit > gasleft() ? gasleft() : gasLimit}(abi.encodeWithSignature("staticcall(address,bytes)", call.to, abi.encodePacked(call.selector, call.data))):
                    wallet.addr.call{gas: gasLimit==0 || gasLimit > gasleft() ? gasleft() : gasLimit}(abi.encodeWithSignature("call(address,uint256,bytes)", call.to, call.value, abi.encodePacked(call.selector, call.data)));
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
                wallet.debt = uint88(/*(tx.gasprice + (gasPriceLimit - tx.gasprice) / 2) * */ (gas - gasleft() + 18000 + (30000/trLength))*110/100);
                // wallet.debt = uint88(/*(tx.gasprice + (gasPriceLimit - tx.gasprice) / 2) * */ (gas - gasleft() + 16000 + (32000/trLength))*110/100);
            }
        }
        require(maxNonce < nonce + (1 << 216), "Factory: gourp+nonce too high");
        s_nonce_group[nonceGroup] = (maxNonce & 0x000000ffffffffff000000000000000000000000000000000000000000000000) + (1 << 192);
      }
    }

    function batchMultiCall2(MCalls2[] calldata tr, uint256 nonceGroup) public {
      unchecked {
        require(msg.sender == s_activator, "Wallet: sender not allowed");
        uint256 nonce = s_nonce_group[nonceGroup] + (uint256(nonceGroup) << 232);
        uint256 maxNonce = 0;
        uint256 trLength = tr.length;
        for(uint256 i = 0; i < trLength; i++) {
            uint256 gas = gasleft();
            MCalls2 calldata mcalls = tr[i];
            bytes memory msg2 = abi.encode(mcalls.typeHash);
            uint256 sessionId = mcalls.sessionId;
            uint256 afterTS = uint40(sessionId >> 152);
            uint256 beforeTS  = uint40(sessionId >> 112);
            uint256 gasPriceLimit  = uint64(sessionId >> 16);

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
            for(uint256 j = 0; j < length; j++) {
                MCall2 calldata call = mcalls.mcall[j];
                address to = call.to;
                msg2 = abi.encodePacked(
                    msg2, 
                    keccak256(abi.encode(call.typeHash, to, call.value, sessionId, afterTS, beforeTS, call.gasLimit, gasPriceLimit, call.selector, call.data))
                );
            }

            bytes32 messageHash = _messageToRecover(
                keccak256(msg2),
                sessionId & FLAG_EIP712 > 0
            );
            
            // emit ErrorHandled(abi.encodePacked(mcalls.r, mcalls.s, mcalls.v));
            // emit ErrorHandled(abi.encodePacked(msg2));
            // emit ErrorHandled(abi.encodePacked(messageHash));
            // return;

            Wallet storage wallet = _getWalletFromMessage(mcalls.signer, messageHash, mcalls.v, mcalls.r, mcalls.s);
            require(wallet.owner == true, "Factory: singer is not owner");

            // uint256 length = mcalls.mcall.length;
            for(uint256 j = 0; j < length; j++) {
                MCall2 calldata call = mcalls.mcall[j];
                uint32 gasLimit = call.gasLimit;
                uint16 flags = call.flags;

                (bool success, bytes memory res) = call.flags & FLAG_STATICCALL > 0 ?
                    wallet.addr.call{gas: gasLimit==0 || gasLimit > gasleft() ? gasleft() : gasLimit}(abi.encodeWithSignature("staticcall(address,bytes)", call.to, abi.encodePacked(call.selector, call.data))):
                    wallet.addr.call{gas: gasLimit==0 || gasLimit > gasleft() ? gasleft() : gasLimit}(abi.encodeWithSignature("call(address,uint256,bytes)", call.to, call.value, abi.encodePacked(call.selector, call.data)));
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
                wallet.debt = uint88(/*(tx.gasprice + (gasPriceLimit - tx.gasprice) / 2) * */ (gas - gasleft() + 18000 + (30000/trLength))*110/100);
                // wallet.debt = uint88(/*(tx.gasprice + (gasPriceLimit - tx.gasprice) / 2) * */ (gas - gasleft() + 16000 + (32000/trLength))*110/100);
            }
        }
        require(maxNonce < nonce + (1 << 216), "Factory: gourp+nonce too high");
        s_nonce_group[nonceGroup] = (maxNonce & 0x000000ffffffffff000000000000000000000000000000000000000000000000) + (1 << 192);
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
        view
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

    fallback() external {
        // solium-disable-next-line security/no-inline-assembly
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
}
