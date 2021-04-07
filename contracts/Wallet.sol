// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v1;

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

    modifier onlyActiveState() {
        require(
            backup.state != BACKUP_STATE_ACTIVATED,
            "Wallet: not active state"
        );
        _;
    }

    function sendEther(address payable _to, uint256 _value)
        public
        onlyActiveOwner()
    {
        require(_value > 0, "value == 0");
        require(_value <= address(this).balance, "value > balance");
        emit SentEther(this.creator(), address(this), _to, _value);
        _to.transfer(_value);
    }

    function transfer20(
        address _token,
        address _to,
        uint256 _value
    ) public onlyActiveOwner() {
        require(_token != address(0), "_token is 0x0");
        emit Transfer20(this.creator(), _token, address(this), _to, _value);
        IERC20(_token).transfer(_to, _value);
    }

    function transferFrom20(
        address _token,
        address _from,
        address _to,
        uint256 _value
    ) public onlyActiveOwner() {
        require(_token != address(0), "_token is 0x0");
        address from = _from == address(0) ? address(this) : address(_from);
        emit Transfer20(this.creator(), _token, from, _to, _value);
        IERC20(_token).transferFrom(_from, _to, _value);
    }

    function transfer721(
        address _token,
        address _to,
        uint256 _value
    ) public onlyActiveOwner() {
        transferFrom721(_token, address(0), _to, _value);
    }

    function transferFrom721(
        address _token,
        address _from,
        address _to,
        uint256 _id
    ) public onlyActiveOwner() {
        require(_token != address(0), "_token is 0x0");
        address from = _from == address(0) ? address(this) : address(_from);
        emit Transfer721(this.creator(), _token, from, _to, _id, "");
        IERC721(_token).transferFrom(address(this), _to, _id);
    }

    function safeTransferFrom721(
        address _token,
        address _from,
        address _to,
        uint256 _id
    ) public onlyActiveOwner() {
        require(_token != address(0), "_token is 0x0");
        address from = _from == address(0) ? address(this) : address(_from);
        emit Transfer721(this.creator(), _token, from, _to, _id, "");
        IERC721(_token).safeTransferFrom(address(this), _to, _id);
    }

    function safeTransferFrom721wData(
        address _token,
        address _from,
        address _to,
        uint256 _id,
        bytes memory _data
    ) public onlyActiveOwner() {
        require(_token != address(0), "_token is 0x0");
        address from = _from == address(0) ? address(this) : address(_from);
        emit Transfer721(this.creator(), _token, from, _to, _id, _data);
        IERC721(_token).safeTransferFrom(address(this), _to, _id, _data);
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function balanceOf20(address _token) public view returns (uint256) {
        return IERC20(_token).balanceOf(address(this));
    }

    function balanceOf721(address _token) public view returns (uint256) {
        return IERC721(_token).balanceOf(address(this));
    }

    function is20Safe(address _token) public view returns (bool) {
        return IOracle(ICreator(this.creator()).oracle()).is20Safe(_token);
    }

    function is721Safe(address _token) public view returns (bool) {
        return IOracle(ICreator(this.creator()).oracle()).is721Safe(_token);
    }

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
        // DOMAIN_SEPARATOR_ASCII = _hashToAscii(DOMAIN_SEPARATOR);
    }

    function version() public pure override returns (bytes8) {
        return bytes8("1.2.1");
    }

    fallback() external {}

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

    function executeCall(
        uint8 v,
        bytes32 r,
        bytes32 s,
        bool eip712,
        uint256 typeHash,
        address to,
        uint256 value,
        bytes calldata data
    ) public onlyActiveState() returns (bytes memory) {
        address activator = ICreator(this.creator()).activator();        
        bytes32 messageData = keccak256(abi.encode(typeHash, activator, to, value, s_nonce, data));
        address addr = ecrecover(_messageToRecover(messageData, eip712), v, r, s);

        require(activator == msg.sender, "Wallet: not an activator");
        require(addr == this.owner(), "Wallet: validation failed");

        s_nonce = s_nonce + 1;
        (bool success, bytes memory res) = to.call{value: value}(data);
        if (!success) {
            revert(_getRevertMsg(res));
        }
        return res;
    }

    function cacnelCall() public onlyActiveOwner() {
        s_nonce = s_nonce + 1;
    }

    function nonce() public view returns (uint32) {
        return s_nonce;
    }

    /*
    function executeCallX(
        uint8 v,
        bytes32 r,
        bytes32 s,
        bool eip712,
        bytes calldata data
    ) public onlyActiveOwner() returns (bool, bytes memory) {
        (
            uint256 typeHash,
            address to,
            uint256 value,
            // bool staticCall,
            bytes memory _data
        ) =
            abi.decode(
                data,
                (
                    uint256,
                    address,
                    uint256,
                    // bool,
                    bytes
                )
            );

        bytes32 message =
            _messageToRecover(
                keccak256(
                    abi.encode(typeHash, msg.sender, to, value, s_nonce, _data)
                ),
                eip712
            );
        address addr = ecrecover(message, v, r, s);

        require(addr == this.owner(), "Wallet: validation failed");
        // require(
        //     uint8(typeHash) ==
        //         uint8(_data[0] << 3) +
        //             uint8(_data[1] << 2) +
        //             uint8(_data[2] << 1) +
        //             uint8(_data[3]),
        //     "Wallet: wrong selector"
        // );

        s_nonce = s_nonce + 1;
        return
            // staticCall ? to.staticcall(_data) :
            to.call{value: value}(_data);
    }
    */

    /*
    function executeCall2(
        address to,
        uint256 value,
        uint8 v,
        bytes32 r,
        bytes32 s,
        bool eip712,
        bool staticCall,
        bytes calldata data
    ) public onlyActiveOwner() returns (bool, bytes memory) {
        bytes32 message =
            _messageToRecover(
                keccak256(abi.encode(msg.sender, to, value, s_nonce, data)),
                eip712
            );
        address addr = ecrecover(message, v, r, s);

        require(addr == this.owner(), "Wallet: validation failed");

        s_nonce = s_nonce + 1;
        return staticCall ? to.staticcall(data) : to.call{value: value}(data);
    }
    */

    /*
    function validateCallMessage(
        address to,
        uint256 value,
        uint8 v,
        bytes32 r,
        bytes32 s,
        bool eip712,
        bytes calldata data
    ) public view onlyActiveOwner() returns (bool) {
        bytes32 message =
            _messageToRecover(
                keccak256(abi.encode(msg.sender, to, value, s_nonce, data)),
                eip712
            );
        address addr = ecrecover(message, v, r, s);
        return addr == this.owner();
    }
*/

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
