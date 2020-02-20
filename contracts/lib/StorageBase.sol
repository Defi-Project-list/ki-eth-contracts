pragma solidity 0.5.16;

interface ICreator {
    function upgradeWallet(bytes8 _id) external;
    function transferWalletOwnership(address _newOwner) external;
    function addWalletBackup(address _wallet) external;
    function removeWalletBackup(address _wallet) external;
    function getLatestVersion() external view returns (address);
    function oracle() external view returns (address);
}

interface IProxy {
    function init(address _owner, address _target) external;
    function owner() external view returns (address);
    function target() external view returns (address);
}

interface IStorage {
    function migrate() external;
    function version() external pure returns (bytes8);
}

interface IStorageBase {
    function owner() external view returns (address);
}

contract StorageBase is IProxy {
    address public owner;
    address public target;

    function owner() external view returns (address) {
        return owner;
    }

    function target() external view returns (address) {
        return target;
    }

    function creator() external view returns (address) {
        return address(0);
    }

    modifier onlyCreator () {
        require (msg.sender == this.creator(), "not creator");
        _;
    }

    modifier onlyOwner () {
        require (msg.sender == owner, "not owner");
        _;
    }

    function init(address _owner, address _target) external onlyCreator() {
        if (_owner != owner && _owner != address(0)) owner = _owner;
        if (_target != target && _target != address(0)) target = _target;
    }

    constructor () public {
        owner = msg.sender;
    }

    function upgrade(bytes8 _version) public onlyOwner() {
        ICreator(this.creator()).upgradeWallet(_version);
    }

}
