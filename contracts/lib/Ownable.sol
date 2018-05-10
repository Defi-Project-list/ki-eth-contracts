pragma solidity 0.4.23;

contract Ownable {
    address public owner;
    address public pendingOwner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "msg.sender != ownder");
        _;
    }

    modifier onlyPendingOwner() {
        require(msg.sender == pendingOwner, "msg.sender != pendingOwner");
        _;
    }

    modifier onlyClaimableOwner() {
        require((msg.sender == owner && pendingOwner == address(0)) || (msg.sender == pendingOwner && pendingOwner != 0));
        _;
    }

    function transferOwnership(address newOwner) onlyOwner public {
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal {
        pendingOwner = newOwner;
    }

    function claimOwnership() onlyPendingOwner public {
        emit OwnershipTransferred(owner, pendingOwner);
        owner = pendingOwner;
        pendingOwner = address(0);
    }

    function reClaimOwnership() onlyOwner public {
        pendingOwner = address(0);
    }

}
