pragma solidity 0.4.24;

contract SWStorageBase {
    address public target;
    address public owner;

    function creator() view external returns (address) {
        return address(this);
    }

    modifier onlyCreator () {
        require (msg.sender == this.creator());
        _;
    }

    modifier onlyOwner () {
        require (msg.sender == owner);
        _;
    }

    function init(address _owner, address _target) onlyCreator() public {
        owner = _owner;
        target = _target;
    }

    function setTarget(address _target) onlyOwner() public {
        target = _target;
    }

}
