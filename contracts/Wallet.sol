// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v2;

//import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC721/IERC721.sol";
import "openzeppelin-solidity/contracts/token/ERC721/IERC721Receiver.sol";

import "./lib/IOracle.sol";
import "./lib/Heritable.sol";

// import "./Trust.sol";

contract Wallet is IStorage, Heritable {
    //using SafeMath for uint256;

    uint8 public constant VERSION_NUMBER = 0x1;
    string public constant NAME = "Kirobo OCW";
    string public constant VERSION = "1";

    event SentEther(
        address indexed creator,
        address indexed owner,
        address indexed to,
        uint256 value
    );
    event Transfer20(
        address indexed creator,
        address indexed token,
        address from,
        address indexed to,
        uint256 value
    );
    event Transfer721(
        address indexed creator,
        address indexed token,
        address from,
        address indexed to,
        uint256 id,
        bytes data
    );

    modifier onlyActiveState() {
        require(
            backup.state != BACKUP_STATE_ACTIVATED,
            "Wallet: not active state"
        );
        _;
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function balanceOf20(address _token) public view returns (uint256) {
        return IERC20(_token).balanceOf(address(this));
    }

    // function balanceOf721(address _token) public view returns (uint256) {
    //     return IERC721(_token).balanceOf(address(this));
    // }

    // function is20Safe(address _token) public view returns (bool) {
    //     return IOracle(ICreator(this.creator()).oracle()).is20Safe(_token);
    // }

    // function is721Safe(address _token) public view returns (bool) {
    //     return IOracle(ICreator(this.creator()).oracle()).is721Safe(_token);
    // }

    //function onERC721Received(address operator, address from, uint256 tokenId, bytes data) public returns (bytes4) {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    // function createTrust(
    //     address _wallet,
    //     uint40 _start,
    //     uint32 _period,
    //     uint16 _times,
    //     uint256 _amount,
    //     bool _cancelable
    // ) public payable {
    //     require(trust == Trust(payable(0)));
    //     trust = (new Trust){value: _amount * _times}(
    //         payable(_wallet),
    //         _start,
    //         _period,
    //         _times,
    //         _amount,
    //         _cancelable
    //     );
    // }

    // function destroyTrust() public {
    //     require(trust != Trust(payable(0)));
    //     trust.destroy();
    //     trust = Trust(payable(0));
    // }

    // function getTrust() public view returns (Trust) {
    //     return trust;
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

    fallback() external {}

    receive() external payable {
        require(false, "Wallet: not aceepting ether");
    }

    struct Call {
        uint8 v;
        bytes32 r;
        bytes32 s;
        bytes32 typeHash;
        address to;
        uint256 value;
        bytes data;
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
        bytes data;
    }

    function executeBatchCall(Call[] calldata tr) public {
        address creator = this.creator();
        address activator = ICreator(creator).activator();
        address owner = this.owner();
        for (uint256 i = 0; i < tr.length; i++) {
            Call memory call = tr[i];
            bytes32 messageData =
                keccak256(
                    abi.encode(
                        call.typeHash,
                        activator,
                        call.to,
                        call.value,
                        s_nonce + i,
                        call.data
                    )
                );
            address signer =
                ecrecover(
                    _messageToRecover(messageData, call.typeHash != bytes32(0)),
                    call.v,
                    call.r,
                    call.s
                );
            require(activator == msg.sender, "Wallet: not an activator");
            require(signer == owner, "Wallet: validation failed");
            require(
                call.to != activator &&
                    call.to != signer &&
                    call.to != address(this) &&
                    call.to != creator,
                "Wallet: reentrancy not allowed"
            );
            (bool success, bytes memory res) =
                call.to.call{value: call.value}(call.data);
            if (!success) {
                revert(_getRevertMsg(res));
            }
        }
        s_nonce = s_nonce + uint32(tr.length);
    }

    function executeCall(
        uint8 v,
        bytes32 r,
        bytes32 s,
        bytes32 typeHash,
        address to,
        uint256 value,
        bytes calldata data
    ) public onlyActiveState() returns (bytes memory) {
        address creator = this.creator();
        address activator = ICreator(creator).activator();
        bytes32 messageData =
            keccak256(
                abi.encode(typeHash, activator, to, value, s_nonce, data)
            );
        address signer =
            ecrecover(
                _messageToRecover(messageData, typeHash != bytes32(0)),
                v,
                r,
                s
            );
        require(activator == msg.sender, "Wallet: not an activator");
        require(signer == this.owner(), "Wallet: validation failed");
        require(
            to != activator &&
                to != signer &&
                to != address(this) &&
                to != creator,
            "Wallet: reentrancy not allowed"
        );
        s_nonce = s_nonce + 1;
        (bool success, bytes memory res) = to.call{value: value}(data);
        if (!success) {
            revert(_getRevertMsg(res));
        }
        return res;
    }

    function executeXCall(
        uint8 v,
        bytes32 r,
        bytes32 s,
        bytes32 typeHash,
        address to,
        uint256 value,
        bytes calldata data
    ) public onlyActiveState() returns (bytes memory) {
        address creator = this.creator();
        address owner = this.owner();
        bytes32 messageData =
            keccak256(abi.encode(typeHash, owner, to, value, s_nonce, data));
        address signer =
            ecrecover(
                _messageToRecover(messageData, typeHash != bytes32(0)),
                v,
                r,
                s
            );
        require(owner == msg.sender, "Wallet: not an owner");
        require(
            signer == ICreator(creator).activator(),
            "Wallet: validation failed"
        );
        require(
            to != owner && to != signer && to != address(this) && to != creator,
            "Wallet: reentrancy not allowed"
        );
        s_nonce = s_nonce + 1;
        (bool success, bytes memory res) = to.call{value: value}(data);
        if (!success) {
            revert(_getRevertMsg(res));
        }
        return res;
    }

    function executeXBatchCall(Call[] calldata tr) public {
        address creator = this.creator();
        address activator = ICreator(creator).activator();
        address owner = this.owner();
        for (uint256 i = 0; i < tr.length; i++) {
            Call memory call = tr[i];
            bytes32 messageData =
                keccak256(
                    abi.encode(
                        call.typeHash,
                        owner,
                        call.to,
                        call.value,
                        s_nonce + i,
                        call.data
                    )
                );
            address signer =
                ecrecover(
                    _messageToRecover(messageData, call.typeHash != bytes32(0)),
                    call.v,
                    call.r,
                    call.s
                );
            require(owner == msg.sender, "Wallet: not an owner");
            require(signer == activator, "Wallet: validation failed");
            require(
                call.to != owner &&
                    call.to != signer &&
                    call.to != address(this) &&
                    call.to != creator,
                "Wallet: reentrancy not allowed"
            );
            (bool success, bytes memory res) =
                call.to.call{value: call.value}(call.data);
            if (!success) {
                revert(_getRevertMsg(res));
            }
        }
        s_nonce = s_nonce + uint32(tr.length);
    }

    function executeXXCall(
        uint8 v1,
        bytes32 r1,
        bytes32 s1,
        uint8 v2,
        bytes32 r2,
        bytes32 s2,
        bytes32 typeHash,
        address to,
        uint256 value,
        bytes calldata data
    ) public onlyActiveState() returns (bytes memory) {
        bytes32 messageData =
            keccak256(abi.encode(typeHash, to, value, s_nonce, data));
        address signer1 =
            ecrecover(
                _messageToRecover(messageData, typeHash != bytes32(0)),
                v1,
                r1,
                s1
            );
        address signer2 =
            ecrecover(
                _messageToRecover(messageData, typeHash != bytes32(0)),
                v2,
                r2,
                s2
            );
        require(signer1 == this.owner(), "Wallet: signer1 not an owner");
        require(
            signer2 == ICreator(this.creator()).activator(),
            "Wallet: signer2 not an activator"
        );
        // require(to != owner && to != signer && to != address(this) && to != creator, "Wallet: reentrancy not allowed");
        s_nonce = s_nonce + 1;
        (bool success, bytes memory res) = to.call{value: value}(data);
        if (!success) {
            revert(_getRevertMsg(res));
        }
        return res;
    }

    function executeXXBatchCall(XCall[] calldata tr) public {
        address creator = this.creator();
        address activator = ICreator(creator).activator();
        address owner = this.owner();
        for (uint256 i = 0; i < tr.length; i++) {
            XCall memory call = tr[i];
            bytes32 messageData =
                keccak256(
                    abi.encode(
                        call.typeHash,
                        call.to,
                        call.value,
                        s_nonce + i,
                        call.data
                    )
                );
            address signer1 =
                ecrecover(
                    _messageToRecover(messageData, call.typeHash != bytes32(0)),
                    call.v1,
                    call.r1,
                    call.s1
                );
            address signer2 =
                ecrecover(
                    _messageToRecover(messageData, call.typeHash != bytes32(0)),
                    call.v2,
                    call.r2,
                    call.s2
                );
            require(signer1 == owner, "Wallet: not an owner");
            require(signer2 == activator, "Wallet: validation failed");
            // require(call.to != owner && call.to != signer && call.to != address(this) && call.to != creator, "Wallet: reentrancy not allowed");
            (bool success, bytes memory res) =
                call.to.call{value: call.value}(call.data);
            if (!success) {
                revert(_getRevertMsg(res));
            }
        }
        s_nonce = s_nonce + uint32(tr.length);
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

    function cacnelCall() public onlyActiveOwner() {
        s_nonce = s_nonce + 1;
    }

    function nonce() public view returns (uint32) {
        return s_nonce;
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
}
