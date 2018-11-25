pragma solidity 0.4.24;

import "../FactoryStorage.sol";

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract FactoryOwnable is FactoryStorage {
  //address public owner; Moved to FactoryStorage

    event OwnershipRenounced(address indexed previousOwner);
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );


//   constructor moved to FactoryStorage
//   /**
//    * @dev The Ownable constructor sets the original `owner` of the contract to the sender
//    * account.
//    */
//   constructor() public {
//     owner = msg.sender;
//   }

//   /**
//    * @dev Throws if called by any account other than the owner.
//    */
//   modifier onlyOwner() {
//     require(msg.sender == owner);
//     _;
//   }

    /**
    * @dev Allows the current owner to relinquish control of the contract.
    * @notice Renouncing to ownership will leave the contract without an owner.
    * It will not be possible to call the functions with the `onlyOwner`
    * modifier anymore.
    */
    function renounceOwnership() public onlyOwner {
        emit OwnershipRenounced(owner);
        owner = address(0);
    }

    /**
    * @dev Allows the current owner to transfer control of the contract to a newOwner.
    * @param _newOwner The address to transfer ownership to.
    */
    function transferOwnership(address _newOwner) public onlyOwner {
        _transferOwnership(_newOwner);
    }

    /**
    * @dev Transfers control of the contract to a newOwner.
    * @param _newOwner The address to transfer ownership to.
    */
    function _transferOwnership(address _newOwner) internal {
        require(_newOwner != address(0), "no new owner");
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }
}
