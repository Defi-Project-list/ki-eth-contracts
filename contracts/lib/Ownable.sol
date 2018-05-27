pragma solidity 0.4.23;

contract Ownable {
    address public owner;
    address public pendingOwner;

    event OwnershipTransferred (address indexed previousOwner, address indexed newOwner);

    constructor () public {
        owner = msg.sender;
    }

    modifier onlyOwner () {
        require (msg.sender == owner, "msg.sender != owner");
        _;
    }

    modifier onlyPendingOwner () {
        require (msg.sender == pendingOwner, "msg.sender != pendingOwner");
        _;
    }

    modifier onlyClaimableOwner () {
        require (msg.sender == owner || (msg.sender == pendingOwner && pendingOwner != 0));
        _;
    }

    function transferOwnership (address _newOwner) onlyOwner public {
        require(_newOwner != owner);
        require(_newOwner != address(0));
        _transferOwnership (_newOwner);
    }

    function _transferOwnership (address _newOwner) internal {
        pendingOwner = _newOwner;
    }

    function claimOwnership () onlyPendingOwner public {
        emit OwnershipTransferred (owner, pendingOwner);
        owner = pendingOwner;
        pendingOwner = address(0);
    }

    function imOwner () external view returns (bool) {
        return (owner == msg.sender);
    }

    function reclaimOwnership () onlyOwner public {
        pendingOwner = address(0);
    }

}
