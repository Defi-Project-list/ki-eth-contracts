pragma solidity 0.4.24;

interface ICreator {
    function upgrade(bytes8 _id) external;
    function changeOwner(address _newOwner) external;
    function addBackup(address _wallet) external;
    function removeBackup(address _wallet) external;
    function getLatestVersion() external view returns (address);
}

interface IProxy {
    function init(address _owner, address _target) external;
    function owner() view external returns (address);
    function target() view external returns (address);
}

interface IStorage {
    function migrate() external;
    function version() pure external returns (bytes8);
}

contract SW_StorageBase is IProxy {
    address public owner;
    address public target;

    function owner() view external returns (address) {
        return owner;
    }

    function target() view external returns (address) {
        return target;
    }

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

    function init(address _owner, address _target) onlyCreator() external {
        if (_owner != owner && _owner != address(0)) owner = _owner;
        if (_target != target && _target != address(0)) target = _target;
    }

    function upgrade(bytes8 _version) onlyOwner() public {
        ICreator(this.creator()).upgrade(_version);
    }

}
