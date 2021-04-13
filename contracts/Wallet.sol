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

    event BatchCall(
        address indexed creator,
        address indexed owner,
        address indexed operator,
        uint256 value
    );

    modifier onlyActiveState() {
        require(
            backup.state != BACKUP_STATE_ACTIVATED,
            "Wallet: not active state"
        );
        _;
    }

    // function getBalance() public view returns (uint256) {
    //     return address(this).balance;
    // }

    // function balanceOf20(address _token) public view returns (uint256) {
    //     return IERC20(_token).balanceOf(address(this));
    // }

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
        // (s_operator, s_activator) = ICreator(msg.sender).managers();
    }

    function version() public pure override returns (bytes8) {
        return bytes8("1.2.1");
    }

    fallback() external {}

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
        address to;
        uint256 value;
        MetaData metaData;
        bytes data;
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

    function _selector(bytes calldata data) private pure returns (bytes4) {
      return data[0] | (bytes4(data[1]) >> 8) | (bytes4(data[2]) >> 16) | (bytes4(data[3]) >> 24);
    }

    struct Entities {
      address creator;
      address operator;
      address owner;  
    }

    function generateMessage(Call calldata call, address activator, uint256 _nonce) public pure returns (bytes memory) {
        return _generateMessage(call, activator, _nonce);
    }

    function generateXXMessage(XCall calldata call, uint256 _nonce) public pure returns (bytes memory) {
        return _generateXXMessage(call, _nonce);
    }

    function _generateMessage(Call calldata call, address activator, uint256 _nonce) private pure returns (bytes memory) {
        return
            call.metaData.simple ?
                abi.encode(call.typeHash, activator, call.to, call.value, _nonce, call.metaData.staticcall ,call.metaData.gasLimit, keccak256(call.data)):
                abi.encode(call.typeHash, activator, call.to, call.value, _nonce, call.metaData.staticcall, call.metaData.gasLimit, _selector(call.data), call.data[4:])
        ;
    }

    function _generateXXMessage(XCall calldata call, uint256 _nonce) private pure returns (bytes memory) {
        return
            call.metaData.simple ?
                abi.encode(call.typeHash, call.to, call.value, _nonce, call.metaData.staticcall ,call.metaData.gasLimit, keccak256(call.data)):
                abi.encode(call.typeHash, call.to, call.value, _nonce, call.metaData.staticcall, call.metaData.gasLimit, _selector(call.data), call.data[4:])
        ;
    }

    function unsecuredBatchCall(Transfer[] calldata tr, Signature calldata sig) public payable onlyActiveState() {
      require(msg.sender == _owner, "Wallet: sender not allowed");
      address creator = this.creator();
      address operator = ICreator(creator).operator();
       
      require(operator != ecrecover(_messageToRecover(keccak256(abi.encode(tr)), false), sig.v, sig.r, sig.s), "Wallet: no operator");
      for(uint256 i = 0; i < tr.length; i++) {
        Transfer calldata call = tr[i];
        (bool success, bytes memory res) = call.metaData.staticcall ? 
            call.to.staticcall{gas: call.metaData.gasLimit > 0 ? call.metaData.gasLimit : gasleft()}(call.data): 
            call.to.call{gas: call.metaData.gasLimit > 0 ? call.metaData.gasLimit : gasleft(), value: call.value}(call.data);
        if (!success) {
            revert(_getRevertMsg(res));
        }
      }
      emit BatchCall(creator, _owner, operator, block.number);
    }

    function executeBatchCall(Call[] calldata tr) public payable onlyActiveState() {
      address creator = this.creator();
      (address s_operator, address s_activator) = ICreator(creator).managers();
      require(msg.sender == s_activator || msg.sender == _owner, "Wallet: sender not allowed");
          
      for(uint256 i = 0; i < tr.length; i++) {
        Call calldata call = tr[i];
        unchecked {  
          address signer = ecrecover(
            _messageToRecover(
              keccak256(_generateMessage(call, msg.sender, i > 0 ? s_nonce + i: s_nonce)),
              call.typeHash != bytes32(0)
            ),
            call.v,
            call.r,
            call.s
          );
          require(signer != msg.sender, "Wallet: sender cannot be signer");
          require(signer == _owner || signer == s_operator, "Wallet: signer not allowed");
          require(call.to != msg.sender && call.to != signer && call.to != address(this) && call.to != creator, "Wallet: reentrancy not allowed");
        }
        (bool success, bytes memory res) = call.metaData.staticcall ? 
            call.to.staticcall{gas: call.metaData.gasLimit > 0 ? call.metaData.gasLimit : gasleft()}(call.data): 
            call.to.call{gas: call.metaData.gasLimit > 0 ? call.metaData.gasLimit : gasleft(), value: call.value}(call.data);
        if (!success) {
            revert(_getRevertMsg(res));
        }
      }
      unchecked {  
        s_nonce = s_nonce + uint32(tr.length);
      }
      emit BatchCall(creator, _owner, s_operator, block.number);
    }

    function executeXXBatchCall(XCall[] calldata tr) public payable onlyActiveState() {
      address creator = this.creator();
      address operator = ICreator(creator).operator();
      
      for(uint i = 0; i < tr.length; i++) {
        XCall calldata call = tr[i];

        unchecked {  
          address signer1 = ecrecover(
            _messageToRecover(
              keccak256(_generateXXMessage(call, i > 0 ? s_nonce + i: s_nonce)),
              call.typeHash != bytes32(0)
            ),
            call.v1,
            call.r1,
            call.s1
          );
          address signer2 = ecrecover(
            _messageToRecover(
              keccak256(_generateXXMessage(call, i > 0 ? s_nonce + i: s_nonce)),
              call.typeHash != bytes32(0)
            ),
            call.v2,
            call.r2,
            call.s2
          );
          require(msg.sender == _owner || msg.sender == operator, "Wallet: sender is not owner nor operator");
          require(signer1 == _owner, "Wallet: signer1 is not owner");
          require(signer2 == operator, "Wallet: signer2 is not operator");          
          require(call.to != signer1 && call.to != signer2 && call.to != address(this) && call.to != creator, "Wallet: reentrancy not allowed");
        }
        (bool success, bytes memory res) = call.metaData.staticcall ? 
            call.to.staticcall{gas: call.metaData.gasLimit > 0 ? call.metaData.gasLimit : gasleft()}(call.data): 
            call.to.call{gas: call.metaData.gasLimit > 0 ? call.metaData.gasLimit : gasleft(), value: call.value}(call.data);
        if (!success) {
            revert(_getRevertMsg(res));
        }
      }
      s_nonce = s_nonce + uint32(tr.length);
      emit BatchCall(creator, _owner, operator, block.number);
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

