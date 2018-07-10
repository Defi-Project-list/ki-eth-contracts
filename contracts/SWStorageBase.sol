pragma solidity 0.4.24;

interface Creator {
    function setTarget(bytes8 _id) external;
}

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

    function setTarget(bytes8 _version) onlyOwner() public {
        Creator(this.creator()).setTarget(_version);
    }

}
