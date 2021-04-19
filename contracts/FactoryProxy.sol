// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v2;

import "./FactoryStorage.sol";
// import "./Factory.sol";

contract FactoryProxy is FactoryStorage {
    bool public frozen;

    constructor(
        address owner1,
        address owner2,
        address owner3
    ) FactoryStorage(owner1, owner2, owner3) {
        // proxy = address(this);
    }

    function setTarget(address _target) public multiSig2of3(0) {
        require(frozen != true, "frozen");
        require(_target != address(0), "no target");
        target = _target;
    }

    function freezeTarget() public multiSig2of3(0) {
        frozen = true;
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


    // keccak256("acceptTokens(address recipient,uint256 value,bytes32 secretHash)");
    bytes32 public constant TRANSFER_TYPEHASH = 0xf728cfc064674dacd2ced2a03acd588dfd299d5e4716726c6d5ec364d16406eb;
    // keccak256("acceptTokens(address recipient,uint256 value,bytes32 secretHash)");
    bytes32 public constant DOMAIN_SEPARATOR = 0xf728cfc064674dacd2ced2a03acd588dfd299d5e4716726c6d5ec364d16406eb;

    // bytes4(keccak256("sendEther(address payable,uint256)"));
    bytes4 public constant TRANSFER_SELECTOR = 0xc61f08fd;

    struct Transfer {
        // uint8 v;
        bytes32 r;
        bytes32 s;
        address token;
        address to;
        uint256 value;
        uint256 sessionId;
        // uint256 gasPriceLimit;
        // uint256 eip712;
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


    function batchTransfer(Transfer[] calldata tr, uint256 nonceGroup) public {
      // address refund = _activator;
      unchecked {
        require(msg.sender == _activator, "Wallet: sender not allowed");
        uint256 nonce = s_nonce_group[nonceGroup] + (uint256(nonceGroup) << 224);
        uint256 maxNonce = 0;
        for(uint256 i = 0; i < tr.length; i++) {
            Transfer calldata call = tr[i];
            address to = call.to;
            uint256 value = call.value;
            address token = call.token;
            uint256 sessionId = call.sessionId;
            uint256 afterTS = uint40(sessionId >> 120);
            uint256 beforeTS  = uint40(sessionId >> 80);
            uint256 gasPriceLimit  = uint64(sessionId >> 16);

            if (maxNonce < sessionId) {
                maxNonce = sessionId;
            }

            require(sessionId >= nonce, "Factory: nonce too low");
            require(tx.gasprice <= gasPriceLimit, "Factory: gas price too high");
            require(block.timestamp > afterTS, "Factory: too early");
            require(block.timestamp < beforeTS, "Factory: too late");

            address wallet = accounts_wallet[ecrecover(
                _messageToRecover(
                    keccak256(abi.encode(TRANSFER_TYPEHASH, token, to, value, sessionId >> 8, afterTS, beforeTS, gasPriceLimit)),
                    sessionId & 0xff00 > 0 // eip712
                ),
                uint8(sessionId), // v
                call.r,
                call.s
            )].addr;

            require(wallet != address(0), "Factory: signer is not owner");
            (bool success, bytes memory res) = token == address(0) ?
                wallet.call(abi.encodeWithSignature("transferEth(address,uint256)", to, value)):
                wallet.call(abi.encodeWithSignature("transferERC20(address,address,uint256)", token, to, value));
            if (!success) {
                revert(_getRevertMsg(res));
            }
        }
        require(maxNonce < nonce + (1 << 192), "Factory: nonce too high");
        s_nonce_group[nonceGroup] = maxNonce << 32 >> 32;
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

    fallback() external {
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            calldatacopy(0x00, 0x00, calldatasize())
            let res := delegatecall(
                gas(),
                sload(target.slot),
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
