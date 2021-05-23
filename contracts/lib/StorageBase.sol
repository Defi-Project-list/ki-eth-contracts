// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v1;

interface ICreator {
    function upgradeWallet(bytes8 id) external;

    function transferWalletOwnership(address newOwner) external;

    function addWalletBackup(address wallet) external;

    function removeWalletBackup(address wallet) external;

    function getLatestVersion() external view returns (address);

    function oracle() external view returns (address);

    function operator() external view returns (address);

    function activator() external view returns (address);

    function managers() external view returns (address, address);
}

interface IProxy {
    function init(address newOwner, address newTarget) external;

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

interface IWallet {
    function sendEther(address payable _to, uint256 _value) external;
}

contract StorageBase is IProxy {
    address internal s_owner;
    address internal s_target;
    uint256 internal s_debt;

    modifier onlyCreator() {
        require(msg.sender == this.creator(), "not creator");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == s_owner, "not owner");
        _;
    }

    constructor() {
        s_owner = msg.sender;
    }

    function init(address newOwner, address newTarget)
        external
        override
        onlyCreator()
    {
        if (newOwner != s_owner && newOwner != address(0)) s_owner = newOwner;
        if (newTarget != s_target && newTarget != address(0)) s_target = newTarget;
        s_debt = 1; //TODO: remove for production
    }

    function upgrade(bytes8 version) external onlyOwner() {
        ICreator(this.creator()).upgradeWallet(version);
    }

    function owner() external view override returns (address) {
        return s_owner;
    }

    function target() external view override returns (address) {
        return s_target;
    }

    // needed to pass compilation
    function creator() external pure returns (address) {
        return address(0);
    }

}
