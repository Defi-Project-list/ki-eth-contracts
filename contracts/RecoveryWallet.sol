// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v1;

import "openzeppelin-solidity/contracts/security/ReentrancyGuard.sol";
import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC721/IERC721.sol";
import "openzeppelin-solidity/contracts/utils/cryptography/SignatureChecker.sol";

import "./lib/IOracle.sol";
import "./lib/Heritable.sol";

contract RecoveryWallet is IStorage, Heritable, ReentrancyGuard {
    using SignatureChecker for address;
    using SafeERC20 for IERC20;
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

    function sendEther(address payable to, uint256 value)
        public
        onlyActiveOwner
        nonReentrant
        returns (bytes memory)
    {
        require(value > 0, "value == 0");
        require(value <= address(this).balance, "value > balance");
        emit SentEther(this.creator(), address(this), to, value);
        (bool sent, bytes memory data) = to.call{value: value}("");
        require(sent, "Failed to send Ether");
        return data;
    }

    function transfer20(
        address token,
        address to,
        uint256 value
    ) public onlyActiveOwner {
        require(token != address(0), "_token is 0x0");
        emit Transfer20(this.creator(), token, address(this), to, value);
        IERC20(token).safeTransfer(to, value);
    }

    function transferFrom20(
        address token,
        address from,
        address to,
        uint256 value
    ) public onlyActiveOwner {
        require(token != address(0), "_token is 0x0");
        address sender = from == address(0) ? address(this) : address(from);
        emit Transfer20(this.creator(), token, sender, to, value);
        IERC20(token).safeTransferFrom(sender, to, value);
    }

    function transfer721(
        address token,
        address to,
        uint256 value
    ) public onlyActiveOwner {
        safeTransferFrom721(token, address(0), to, value);
    }

    function safeTransferFrom721(
        address token,
        address from,
        address to,
        uint256 id
    ) public onlyActiveOwner {
        require(token != address(0), "_token is 0x0");
        address sender = from == address(0) ? address(this) : address(from);
        emit Transfer721(this.creator(), token, sender, to, id, "");
        IERC721(token).safeTransferFrom(sender, to, id);
    }

    function safeTransferFrom721wData(
        address token,
        address from,
        address to,
        uint256 id,
        bytes memory data
    ) public onlyActiveOwner {
        require(token != address(0), "token is 0x0");
        emit Transfer721(
            this.creator(),
            token,
            from == address(0) ? address(this) : from,
            to,
            id,
            data
        );
        IERC721(token).safeTransferFrom(from, to, id, data);
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function balanceOf20(address token) public view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function balanceOf721(address token) public view returns (uint256) {
        return IERC721(token).balanceOf(address(this));
    }

    function is20Safe(address token) public view returns (bool) {
        return IOracle(ICreator(this.creator()).oracle()).is20Safe(token);
    }

    function is721Safe(address token) public view returns (bool) {
        return IOracle(ICreator(this.creator()).oracle()).is721Safe(token);
    }

    function migrate() external override onlyCreator {
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
        return bytes8("REC-0.1");
    }

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

    function execute(
        address to,
        uint256 value,
        bytes calldata data
    ) public onlyActiveOwner returns (bytes memory) {
        (bool success, bytes memory res) = to.call{value: value}(data);
        if (!success) {
            revert(_getRevertMsg(res));
        }
        return res;
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
}
