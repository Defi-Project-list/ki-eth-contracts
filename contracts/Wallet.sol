// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v2;

import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC721/IERC721.sol";
import "openzeppelin-solidity/contracts/utils/cryptography/SignatureChecker.sol";

import "./lib/IOracle.sol";
import "./lib/Heritable.sol";

// import "./Trust.sol";

contract Wallet is IStorage, Heritable {
    using SignatureChecker for address;

    uint8 public constant VERSION_NUMBER = 0x1;
    string public constant NAME = "Kirobo OCW";
    string public constant VERSION = "1";

    event BatchCall(
        address indexed creator,
        address indexed owner,
        address indexed activator,
        uint256 value
    );

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function balanceOf20(address token) public view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function balanceOf721(address token) public view returns (uint256) {
        return IERC721(token).balanceOf(address(this));
    }

    // function is20Safe(address _token) public view returns (bool) {
    //     return IOracle(ICreator(this.creator()).oracle()).is20Safe(_token);
    // }

    // function is721Safe(address _token) public view returns (bool) {
    //     return IOracle(ICreator(this.creator()).oracle()).is721Safe(_token);
    // }

    // function createTrust(
    //     address _wallet,
    //     uint40 _start,
    //     uint32 _period,
    //     uint16 _times,
    //     uint256 _amount,
    //     bool _cancelable
    // ) public payable {
    //     require(s_trust == Trust(payable(0)));
    //     s_trust = (new Trust){value: _amount * _times}(
    //         payable(_wallet),
    //         _start,
    //         _period,
    //         _times,
    //         _amount,
    //         _cancelable
    //     );
    // }

    // function destroyTrust() public {
    //     require(s_trust != Trust(payable(0)));
    //     s_trust.destroy();
    //     s_trust = Trust(payable(0));
    // }

    // function getTrust() public view returns (Trust) {
    //     return s_trust;
    // }

    // IStorage Implementation
    function migrate() external override onlyCreator() {
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

    function version() public pure override returns (bytes8) {
        return bytes8("1.2.1");
    }

    // function isValidSignature(bytes32 msgHash, bytes memory signature) external view onlyActiveState() returns (bytes4) {
    //     require(s_owner.isValidSignatureNow(msgHash, signature), "Wallet: signer is not owner");
    //     return SELECTOR_IS_VALID_SIGNATURE;
    // }

    fallback() external {
        if (
            msg.sig == SELECTOR_ON_ERC721_RECEIVED ||
            msg.sig == SELECTOR_ON_ERC1155_RECEIVED ||
            msg.sig == SELECTOR_ON_ERC1155_BATCH_RECEIVED
        ) {
            assembly {
                calldatacopy(0, 0, 0x04)
                return(0, 0x20)
            }
        }
    }

    receive() external payable {
        require(false, "Wallet: not aceepting ether");
    }

    struct MetaData {
        bool simple;
        bool staticcall;
        uint32 gasLimit;
    }

    struct Call {
        uint8 v;
        bytes32 r;
        bytes32 s;
        bytes32 typeHash;
        address to;
        uint256 value;
        MetaData metaData;
        bytes data;
    }

    struct Transfer {
        uint8 v;
        bytes32 r;
        bytes32 s;
        address to;
        uint256 value;
    }

    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    struct Send {
        uint8 v;
        bytes32 r;
        bytes32 s;
        address to;
        uint256 value;
        bool eip712;
    }

    struct XCall {
        uint8 v1;
        bytes32 r1;
        bytes32 s1;
        uint8 v2;
        bytes32 r2;
        bytes32 s2;
        bytes32 typeHash;
        address to;
        uint256 value;
        MetaData metaData;
        bytes data;
    }

    function blockTransaction(bytes32 messageHash) external onlyOwner() {
        require(messageHash != bytes32(0), "blocking 0x0 is not allowed");
        s_blocked[messageHash] = 1;
    }

    function unblockTransaction(bytes32 messageHash) external onlyOwner() {
        s_blocked[messageHash] = 0;
    }

    function _selector(bytes calldata data) private pure returns (bytes4) {
        return
            data[0] |
            (bytes4(data[1]) >> 8) |
            (bytes4(data[2]) >> 16) |
            (bytes4(data[3]) >> 24);
    }

    function erc20BalanceGT(
        address token,
        address account,
        uint256 value
    ) external view {
        require(
            IERC20(token).balanceOf(account) >= value,
            "ERC20Balance: too low"
        );
    }

    function generateMessage(
        Call calldata call,
        address activator,
        uint256 targetNonce
    ) public pure returns (bytes memory) {
        return _generateMessage(call, activator, targetNonce);
    }

    function generateXXMessage(XCall calldata call, uint256 targetNonce)
        public
        pure
        returns (bytes memory)
    {
        return _generateXXMessage(call, targetNonce);
    }

    function _generateMessage(
        Call calldata call,
        address activator,
        uint256 targetNonce
    ) private pure returns (bytes memory) {
        return
            call.metaData.simple
                ? abi.encode(
                    call.typeHash,
                    activator,
                    call.to,
                    call.value,
                    targetNonce,
                    call.metaData.staticcall,
                    call.metaData.gasLimit,
                    keccak256(call.data)
                )
                : abi.encode(
                    call.typeHash,
                    activator,
                    call.to,
                    call.value,
                    targetNonce,
                    call.metaData.staticcall,
                    call.metaData.gasLimit,
                    _selector(call.data),
                    call.data[4:]
                );
    }

    function _generateXXMessage(XCall calldata call, uint256 targetNonce)
        private
        pure
        returns (bytes memory)
    {
        return
            call.metaData.simple
                ? abi.encode(
                    call.typeHash,
                    call.to,
                    call.value,
                    targetNonce,
                    call.metaData.staticcall,
                    call.metaData.gasLimit,
                    keccak256(call.data)
                )
                : abi.encode(
                    call.typeHash,
                    call.to,
                    call.value,
                    targetNonce,
                    call.metaData.staticcall,
                    call.metaData.gasLimit,
                    _selector(call.data),
                    call.data[4:]
                );
    }

    // function unsecuredBatchCall(Transfer[] calldata tr, Signature calldata sig) public payable onlyActiveState() {
    //   require(msg.sender == _owner, "Wallet: sender not allowed");
    //   address creator = this.creator();
    //   address operator = ICreator(creator).operator();

    //   require(operator != ecrecover(_messageToRecover(keccak256(abi.encode(tr)), false), sig.v, sig.r, sig.s), "Wallet: no operator");
    //   for(uint256 i = 0; i < tr.length; i++) {
    //     Transfer calldata call = tr[i];
    //     (bool success, bytes memory res) = call.metaData.staticcall ?
    //         call.to.staticcall{gas: call.metaData.gasLimit > 0 ? call.metaData.gasLimit : gasleft()}(call.data):
    //         call.to.call{gas: call.metaData.gasLimit > 0 ? call.metaData.gasLimit : gasleft(), value: call.value}(call.data);
    //     if (!success) {
    //         revert(_getRevertMsg(res));
    //     }
    //   }
    //   emit BatchCall(creator, _owner, operator, block.number);
    // }

    // keccak256("acceptTokens(address recipient,uint256 value,bytes32 secretHash)");
    // bytes32 public constant ACCEPT_TYPEHASH = 0xf728cfc064674dacd2ced2a03acd588dfd299d5e4716726c6d5ec364d16406eb;

    // function unsecuredBatchCall(Transfer[] calldata tr) public payable onlyActiveState() {
    //   require(msg.sender != this.creator(), "Wallet: sender not allowed");
    //   uint32 nonce = s_nonce;
    //   address owner = _owner;
    //   for(uint256 i = 0; i < tr.length; i++) {
    //     Transfer calldata call = tr[i];
    //     unchecked {
    //       address signer = ecrecover(
    //         _messageToRecover(
    //           // keccak256(_generateMessage(call, msg.sender, i > 0 ? nonce + i: nonce)),
    //           // call.typeHash != bytes32(0)
    //           keccak256(abi.encode(ACCEPT_TYPEHASH, call.to, call.value, nonce + i)),
    //           false)
    //         ,
    //         call.v,
    //         call.r,
    //         call.s
    //       );
    //       require(signer != owner, "Wallet: signer is not owner");
    //       // require(call.to != msg.sender && call.to != signer && call.to != address(this) && call.to != this.creator(), "Wallet: reentrancy not allowed");
    //     }
    //     payable(call.to).transfer(call.value);
    //     // (bool success, bytes memory res) = call.metaData.staticcall ?
    //     //     call.to.staticcall{gas: call.metaData.gasLimit > 0 ? call.metaData.gasLimit : gasleft()}(call.data):
    //     //     call.to.call{gas: call.metaData.gasLimit > 0 ? call.metaData.gasLimit : gasleft(), value: call.value}(call.data);
    //     // if (!success) {
    //     //     revert(_getRevertMsg(res));
    //     // }
    //   }
    // }

    function executeBatchCall(Call[] calldata tr)
        public
        payable
        onlyActiveState()
    {
        address creator = this.creator();
        // (address operator, address activator) = ICreator(creator).managers();
        address activator = ICreator(creator).activator();
        uint32 currentNonce = s_nonce;
        address owner = s_owner;
        require(
            msg.sender == activator || msg.sender == owner,
            "Wallet: sender not allowed"
        );

        for (uint256 i = 0; i < tr.length; i++) {
            Call calldata call = tr[i];
            address to = call.to;
            uint256 gasLimit = call.metaData.gasLimit;
            unchecked {
                address signer = ecrecover(
                    _messageToRecover(
                        keccak256(
                            _generateMessage(call, msg.sender, currentNonce + i)
                        ),
                        call.typeHash != bytes32(0)
                    ),
                    call.v,
                    call.r,
                    call.s
                );
                require(
                    signer != msg.sender,
                    "Wallet: sender cannot be signer"
                );
                require(
                    signer == owner || signer == activator,
                    "Wallet: signer not allowed"
                );
                require(
                    to != msg.sender &&
                        to != signer &&
                        to != address(this) &&
                        to != creator,
                    "Wallet: reentrancy not allowed"
                );
            }
            (bool success, bytes memory res) = call.metaData.staticcall
                ? to.staticcall{gas: gasLimit > 0 ? gasLimit : gasleft()}(
                    call.data
                )
                : to.call{
                    gas: gasLimit > 0 ? gasLimit : gasleft(),
                    value: call.value
                }(call.data);
            if (!success) {
                revert(_getRevertMsg(res));
            }
        }
        unchecked {
            s_nonce = currentNonce + uint32(tr.length);
        }
        emit BatchCall(creator, owner, activator, block.number);
    }

    function executeXXBatchCall(XCall[] calldata tr)
        public
        payable
        onlyActiveState()
    {
        address creator = this.creator();
        address activator = ICreator(creator).activator();
        require(
            msg.sender == s_owner || msg.sender == activator,
            "Wallet: sender is not owner nor activator"
        );

        for (uint256 i = 0; i < tr.length; i++) {
            XCall calldata call = tr[i];

            unchecked {
                address signer1 = ecrecover(
                    _messageToRecover(
                        keccak256(_generateXXMessage(call, s_nonce + i)),
                        call.typeHash != bytes32(0)
                    ),
                    call.v1,
                    call.r1,
                    call.s1
                );
                address signer2 = ecrecover(
                    _messageToRecover(
                        keccak256(_generateXXMessage(call, s_nonce + i)),
                        call.typeHash != bytes32(0)
                    ),
                    call.v2,
                    call.r2,
                    call.s2
                );
                require(signer1 == s_owner, "Wallet: signer1 is not owner");
                require(
                    signer2 == activator,
                    "Wallet: signer2 is not activator"
                );
                require(
                    call.to != signer1 &&
                        call.to != signer2 &&
                        call.to != address(this) &&
                        call.to != creator,
                    "Wallet: reentrancy not allowed"
                );
            }
            (bool success, bytes memory res) = call.metaData.staticcall
                ? call.to.staticcall{
                    gas: call.metaData.gasLimit > 0
                        ? call.metaData.gasLimit
                        : gasleft()
                }(call.data)
                : call.to.call{
                    gas: call.metaData.gasLimit > 0
                        ? call.metaData.gasLimit
                        : gasleft(),
                    value: call.value
                }(call.data);
            if (!success) {
                revert(_getRevertMsg(res));
            }
        }
        s_nonce = s_nonce + uint32(tr.length);
        emit BatchCall(creator, s_owner, activator, block.number);
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

    function cancelCall() public onlyActiveOwner() {
        s_nonce = s_nonce + 1;
    }

    function nonce() public view returns (uint32) {
        return s_nonce;
    }

    // function transferEth(address payable _to, uint256 _value)
    //     public
    //     onlyCreator()
    // {
    //     _to.transfer(_value);
    // }

    // function transferERC20(/*address refundToken, address payable refund,*/address _token, address payable _to, uint256 _value)
    //     external
    //     onlyCreator()
    // {
    //     (bool success, bytes memory res) =
    //         _token.call(abi.encodeWithSignature("transfer(address,uint256)", _to, _value));
    //     if (!success) {
    //         revert(_getRevertMsg(res));
    //     }
    //     // (bool success2, bytes memory res2) =
    //     //     refundToken.call{gas: 80000}(abi.encodeWithSignature("transfer(address,uint256)", refund, _value));
    //     // if (!success2) {
    //     //     revert(_getRevertMsg(res2));
    //     // }
    // }

    // function transfer(/*address payable refund,*/ address token, address payable to, uint256 value)
    //     public
    //     onlyCreator()
    // {
    //     if (token == address(0)) {
    //         to.transfer(value);
    //         //refund.transfer(tx.gasprice * 5000);
    //     } else {
    //         (bool success, bytes memory res) =
    //             token.call{gas: 80000}(abi.encodeWithSignature("transfer(address,uint256)", to, value));
    //         if (!success) {
    //             revert(_getRevertMsg(res));
    //         }
    //     }
    // }

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
}
