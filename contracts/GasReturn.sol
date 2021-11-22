// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/utils/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";
contract GasReturn {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    address public owner;
    uint256 public balance;

    struct User{
        address userAddr;
        uint256 amount;
        uint256 lockedUntil;
    }

    event TransferReceived(address from, uint256 amount);
    event TransferSent(address from, address to, uint256 amount);

    mapping (bytes32 => uint256) userStructs;
    mapping (bytes32 => User) userAddresses;

    constructor () {
        owner = msg.sender;
    }
    receive() payable external {
        balance += msg.value;
        addUserToContract(msg.sender, msg.value);
        emit TransferReceived(msg.sender, msg.value);
    }

    function withdraw(uint amount, address payable to) public {
        require(msg.sender == owner, "Only owner can withdraw funds");
        require(amount <= balance, "insufficient funds");
        to.transfer(amount);
        balance -= amount;
        emit TransferSent(msg.sender, to, amount);
    }

    function transferERC20(IERC20 token, address to, uint256 amount) public {
        bytes32 id = keccak256(abi.encode(to, amount));
        uint256 tr = userStructs[id];
        require(tr > 0, "SafeTransfer: request not exist");
        User memory user = userAddresses[id];
        require(user.lockedUntil <= block.timestamp, "too early");
        delete userStructs[id];
        delete userAddresses[id];

        uint256 erc20balance = token.balanceOf(address(this));
        require(user.amount <= erc20balance, "balance in contract is too low");
        balance -= user.amount;
        IERC20(token).safeTransferFrom(owner, user.userAddr, user.amount);
        emit TransferSent(msg.sender, user.userAddr, user.amount);
    }

    function addUserToContract(address _from,uint256 _amount) public {
        User memory user;
        user.userAddr = _from;
        user.amount = _amount;
        user.lockedUntil = block.timestamp + 180 days;

        bytes32 id = keccak256(abi.encode(user.userAddr, user.amount));
        userStructs[id] = 0xffffffffffffffff;
        userAddresses[id] = user;
    }
}