pragma solidity 0.4.23;

import "./Ownable.sol";

contract Heritable is Ownable {
    address private heir_;

    // Time window the owner has to notify they are alive.
    uint256 private heartbeatTimeout_;

    // Timestamp of the owner's death, as pronounced by the heir.
    uint256 private timeOfDeath_;

    event HeirChanged(address indexed owner, address indexed newHeir);
    event OwnerHeartbeated(address indexed owner);
    event OwnerProclaimedDead(address indexed owner, address indexed heir, uint256 timeOfDeath);
    event HeirOwnershipClaimed(address indexed previousOwner, address indexed newOwner);

    modifier onlyHeir() {
        require(msg.sender == heir_);
        _;
    }

    constructor(uint256 _heartbeatTimeout) public {
        setHeartbeatTimeout(_heartbeatTimeout);
    }

    function setHeir(address newHeir) public onlyOwner {
        require(newHeir != owner);
        heartbeat();
        emit HeirChanged(owner, newHeir);
        heir_ = newHeir;
    }

    function heir() public view returns(address) {
        return heir_;
    }

    function heartbeatTimeout() public view returns(uint256) {
        return heartbeatTimeout_;
    }

    function timeOfDeath() public view returns(uint256) {
        return timeOfDeath_;
    }

    function removeHeir() public onlyOwner {
        heartbeat();
        heir_ = 0;
    }

    function proclaimDeath() public onlyHeir {
        require(ownerLives());
        emit OwnerProclaimedDead(owner, heir_, timeOfDeath_);
        // solium-disable-next-line security/no-block-members
        timeOfDeath_ = block.timestamp;
    }

    function heartbeat() public onlyOwner {
        emit OwnerHeartbeated(owner);
        timeOfDeath_ = 0;
    }

    function claimHeirOwnership() public onlyHeir {
        require(!ownerLives());
        // solium-disable-next-line security/no-block-members
        require(block.timestamp >= timeOfDeath_ + heartbeatTimeout_);
        emit OwnershipTransferred(owner, heir_);
        emit HeirOwnershipClaimed(owner, heir_);
        owner = heir_;
        timeOfDeath_ = 0;
    }

    function setHeartbeatTimeout(uint256 newHeartbeatTimeout) internal onlyOwner {
        require(ownerLives());
        heartbeatTimeout_ = newHeartbeatTimeout;
    }

    function ownerLives() internal view returns (bool) {
        return timeOfDeath_ == 0;
    }
}
