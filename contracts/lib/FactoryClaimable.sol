// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v1;

import "./FactoryOwnable.sol";

/**
 * @title Claimable
 * @dev Extension for the Ownable contract, where the ownership needs to be claimed.
 * This allows the new owner to accept the transfer.
 */
abstract contract FactoryClaimable is FactoryOwnable {
    //address public pendingOwner; Moved to FactoryStorage

    /**
     * @dev Modifier throws if called by any account other than the pendingOwner.
     */
    modifier onlyPendingOwner() {
        // require(msg.sender == pendingOwner, "not pending owner");
        _;
    }

    /**
     * @dev Allows the current owner to set the pendingOwner address.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(
        address newOwner /*onlyOwner*/
    ) public pure override {
        // pendingOwner = newOwner;
    }

    /**
     * @dev Allows the pendingOwner address to finalize the transfer.
     */
    function claimOwnership() public onlyPendingOwner {
        // emit OwnershipTransferred(owner, pendingOwner);
        // owner = pendingOwner;
        // pendingOwner = address(0);
    }
}
