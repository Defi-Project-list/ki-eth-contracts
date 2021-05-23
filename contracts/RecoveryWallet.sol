// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v1;

import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC721/IERC721.sol";
import "openzeppelin-solidity/contracts/utils/cryptography/SignatureChecker.sol";

import "./lib/IOracle.sol";
import "./lib/Heritable.sol";

// import "./Trust.sol";

contract RecoveryWallet is IStorage, Heritable {
    using SignatureChecker for address;

    uint8 public constant VERSION_NUMBER = 0x1;
    string public constant NAME = "Kirobo OCW";
    string public constant VERSION = "1";

    // bytes public DOMAIN_SEPARATOR_ASCII;

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
        onlyActiveOwner()
    {
        require(value > 0, "value == 0");
        require(value <= address(this).balance, "value > balance");
        emit SentEther(this.creator(), address(this), to, value);
        to.transfer(value);
    }

    function transfer20(
        address token,
        address to,
        uint256 value
    ) public onlyActiveOwner() {
        require(token != address(0), "_token is 0x0");
        emit Transfer20(this.creator(), token, address(this), to, value);
        IERC20(token).transfer(to, value);
    }

    function transferFrom20(
        address token,
        address from,
        address to,
        uint256 value
    ) public onlyActiveOwner() {
        require(token != address(0), "_token is 0x0");
        address sender = from == address(0) ? address(this) : address(from);
        emit Transfer20(this.creator(), token, sender, to, value);
        IERC20(token).transferFrom(sender, to, value);
    }

    function transfer721(
        address token,
        address to,
        uint256 value
    ) public onlyActiveOwner() {
        transferFrom721(token, address(0), to, value);
    }

    function transferFrom721(
        address token,
        address from,
        address to,
        uint256 id
    ) public onlyActiveOwner() {
        require(token != address(0), "_token is 0x0");
        emit Transfer721(this.creator(), token, from == address(0) ? address(this) : address(from), to, id, "");
        IERC721(token).transferFrom(address(this), to, id);
    }

    function safeTransferFrom721(
        address token,
        address from,
        address to,
        uint256 id
    ) public onlyActiveOwner() {
        require(token != address(0), "_token is 0x0");
        emit Transfer721(this.creator(), token, from == address(0) ? address(this) : address(from), to, id, "");
        IERC721(token).safeTransferFrom(address(this), to, id);
    }

    function safeTransferFrom721wData(
        address token,
        address from,
        address to,
        uint256 id,
        bytes memory data
    ) public onlyActiveOwner() {
        require(token != address(0), "token is 0x0");
        emit Transfer721(this.creator(), token, from == address(0) ? address(this) : address(from), to, id, data);
        IERC721(token).safeTransferFrom(address(this), to, id, data);
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

    //function onERC721Received(address operator, address from, uint256 tokenId, bytes data) public returns (bytes4) {
    // function onERC721Received(
    //     address,
    //     address,
    //     uint256,
    //     bytes memory
    // ) public pure returns (bytes4) {
    //     return this.onERC721Received.selector;
    // }

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
        // DOMAIN_SEPARATOR_ASCII = _hashToAscii(DOMAIN_SEPARATOR);
    }

    function version() public pure override returns (bytes8) {
        return bytes8("REC-0.1");
    }

    // function isValidSignature(bytes32 msgHash, bytes memory signature) external view onlyActiveState() returns (bytes4) {
    //     require(s_owner.isValidSignatureNow(msgHash, signature), "Wallet: signer is not owner");
    //     return SELECTOR_IS_VALID_SIGNATURE;
    // }

    fallback() external {
        if(
            msg.sig == SELECTOR_ON_ERC721_RECEIVED ||
            msg.sig == SELECTOR_ON_ERC1155_RECEIVED ||
            msg.sig == SELECTOR_ON_ERC1155_BATCH_RECEIVED
        ) 
        {
            assembly {                
                calldatacopy(0, 0, 0x04)
                return (0, 0x20)
            }
        }
    }

    receive() external payable {
        require(false, "Wallet: not aceepting ether");
    }

    function execute(
        address to,
        uint256 value,
        bytes calldata data
    ) public onlyActiveOwner() returns (bytes memory) {
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
