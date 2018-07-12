pragma solidity 0.4.24;

interface Creator {
    function upgrade(bytes8 _id) external;
    function changeOwner(address _newOwner) external;
    function addBackup(address _wallet) external;
    function removeBackup(address _wallet) external;
    function getLatestVersion() external view returns (address);
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
        if (owner != _owner) owner = _owner;
        if (target != _target) target = _target;
    }

    function upgrade(bytes8 _version) onlyOwner() public {
        Creator(this.creator()).upgrade(_version);
    }

}
