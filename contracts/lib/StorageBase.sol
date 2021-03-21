// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

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
    address internal _owner;
    address internal _target;

    function owner() external view override returns (address) {
        return _owner;
    }

    function target() external view override returns (address) {
        return _target;
    }

    function creator() external pure returns (address) {
        return address(0);
    }

    modifier onlyCreator () {
        require (msg.sender == this.creator(), "not creator");
        _;
    }

    modifier onlyOwner () {
        require (msg.sender == _owner, "not owner");
        _;
    }

    function init(address __owner, address __target) external onlyCreator() override {
        if (__owner != _owner && __owner != address(0)) _owner = __owner;
        if (__target != _target && __target != address(0)) _target = __target;
    }

    constructor () {
        _owner = msg.sender;
    }

    function upgrade(bytes8 _version) public onlyOwner() {
        ICreator(this.creator()).upgradeWallet(_version);
    }

}
