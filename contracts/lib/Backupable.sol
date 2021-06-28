// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v1;

import "./IOracle.sol";
import "./Interface.sol";
import "./StorageBase.sol";
import "./Storage.sol";

/**
 * @dev Backupable contract intreduces the functionality of backup wallet
 *
 * an owner of the wallet can set a different wallet as a backup wallet
 * after activation and time setting the wallet ownership can be reclaimed by
 * the backup wallet owner
 */

abstract contract Backupable is IStorage, StorageBase, Storage, Interface {
    event BackupChanged(
        address indexed creator,
        address indexed owner,
        address indexed wallet,
        uint32 timeout,
        uint40 timestamp,
        uint8 state
    );
    event BackupRemoved(
        address indexed creator,
        address indexed owner,
        address indexed wallet,
        uint8 state
    );
    event BackupRegistered(
        address indexed creator,
        address indexed wallet,
        uint8 state
    );
    event BackupEnabled(
        address indexed creator,
        address indexed wallet,
        uint40 timestamp,
        uint8 state
    );
    event BackupActivated(
        address indexed creator,
        address indexed wallet,
        address indexed activator,
        uint8 state
    );
    event BackupPayment(
        address indexed creator,
        address indexed payee,
        uint256 amount,
        bool reward
    );
    event OwnershipTransferred(
        address indexed creator,
        address indexed previousOwner,
        address indexed newOwner,
        uint8 state
    );
    event OwnershipReclaimed(
        address indexed creator,
        address indexed owner,
        address indexed pendingOwner,
        uint8 state
    );

    modifier onlyActiveOwner() {
        require(
            msg.sender == this.owner() &&
                s_backup.state != BACKUP_STATE_ACTIVATED,
            "not active owner"
        );
        _;
    }

    modifier onlyBackup() {
        require(msg.sender == s_backup.wallet, "not backup");
        _;
    }

    modifier eitherOwnerOrBackup() {
        require(
            msg.sender == s_owner || msg.sender == s_backup.wallet,
            "neither owner nor backup"
        );
        _;
    }

    /*
     * @dev this function sets the backup wallet to a specific activeOwner
     * @params - wallet (type address)
     *           timeout (type uint32)
     *
     * Requirements: 1. must enter a wallet address
     *               2. owner wallet address must be different then the backup wallet address
     *
     * Caution: this operation will override the previous backup wallet
     */
    function setBackup(address wallet, uint32 timeout)
        external
        onlyActiveOwner
    {
        require(wallet != address(0), "no backup");
        require(wallet != s_owner, "backup is owner");

        if (s_backup.wallet != wallet) {
            if (s_backup.wallet != address(0)) {
                ICreator(this.creator()).removeWalletBackup(s_backup.wallet);
            }
            s_backup.wallet = wallet;
            ICreator(this.creator()).addWalletBackup(wallet);
            if (s_backup.state != BACKUP_STATE_PENDING)
                s_backup.state = BACKUP_STATE_PENDING;
            if (s_backup.timestamp != 0) s_backup.timestamp = 0;
        }
        if (s_backup.timeout != timeout) s_backup.timeout = timeout;
        if (s_backup.state == BACKUP_STATE_ENABLED) {
            s_backup.timestamp = getBlockTimestamp();
        }
        emit BackupChanged(
            this.creator(),
            s_owner,
            wallet,
            timeout,
            s_backup.timestamp,
            s_backup.state
        );
    }

    /**
     * @dev removes the owner's backup wallet
     */
    function removeBackup() external onlyOwner {
        require(s_backup.wallet != address(0), "backup not exist");
        _removeBackup();
    }

    /**
     * @dev activates backup wallet
     *
     * contitions: 1. backup is enabled
     *             2. backup wallet needs to be set
     *             3. backup time that was set is now 0
     */
    function activateBackup() external {
        require(s_backup.state == BACKUP_STATE_ENABLED, "backup not enabled");
        require(s_backup.wallet != address(0), "backup not exist");
        require(getBackupTimeLeft() == 0, "too early");
        //require (msg.sender == tx.origin);

        if (s_backup.state != BACKUP_STATE_ACTIVATED)
            s_backup.state = BACKUP_STATE_ACTIVATED;
        emit BackupActivated(
            this.creator(),
            s_backup.wallet,
            msg.sender,
            s_backup.state
        );

        uint256 currentBalance = address(this).balance;
        address payable payee = IOracle(ICreator(this.creator()).oracle())
        .paymentAddress();

        unchecked {
            if (payee.send(currentBalance / 100)) {
                emit BackupPayment(
                    this.creator(),
                    payee,
                    currentBalance / 100,
                    false
                );
            }

            payable(msg.sender).transfer(currentBalance / 1000);
            emit BackupPayment(
                this.creator(),
                msg.sender,
                currentBalance / 1000,
                true
            );
        }
    }

    /**
     * @dev once a backup wallet was activated the ownership of the original wallet needs to be
     * claimed by the owner of the backup wallet
     *
     * restrictions: 1. only the backup wallet owner can claim the original wallet
     *               2. backup status needs to be active
     */
    function claimOwnership() external onlyBackup {
        require(
            s_backup.state == BACKUP_STATE_ACTIVATED,
            "backup not activated"
        );
        s_backup.state = BACKUP_STATE_PENDING;
        emit OwnershipTransferred(
            this.creator(),
            s_owner,
            s_backup.wallet,
            s_backup.state
        );
        if (s_owner != s_backup.wallet)
            ICreator(this.creator()).transferWalletOwnership(s_backup.wallet);
        s_backup.wallet = address(0);
        if (s_backup.timeout != 0) s_backup.timeout = 0;
        if (s_backup.timestamp != 0) s_backup.timestamp = 0;
    }

    /**
     * @dev the owner that created the backup wallet can reclaim the account back
     * restrictions: 1. only the original wallet owner can reclaim his original wallet
     *               2. backup status needs to be active
     */
    function reclaimOwnership() external onlyOwner {
        require(
            s_backup.state == BACKUP_STATE_ACTIVATED,
            "backup not activated"
        );
        s_backup.state = BACKUP_STATE_REGISTERED;
        emit OwnershipReclaimed(
            this.creator(),
            s_owner,
            s_backup.wallet,
            s_backup.state
        );
    }

    function enable() external eitherOwnerOrBackup {
        require(
            s_backup.state == BACKUP_STATE_REGISTERED,
            "backup not registered"
        );
        uint40 timestamp = getBlockTimestamp();
        s_backup.state = BACKUP_STATE_ENABLED;
        s_backup.timestamp = timestamp;
        emit BackupEnabled(
            this.creator(),
            s_backup.wallet,
            timestamp,
            s_backup.state
        );
    }

    function accept() external onlyBackup {
        require(s_backup.state == BACKUP_STATE_PENDING, "backup not pending");
        s_backup.state = BACKUP_STATE_REGISTERED;
        emit BackupRegistered(this.creator(), s_backup.wallet, s_backup.state);
    }

    function decline() external onlyBackup {
        require(s_backup.state == BACKUP_STATE_PENDING, "backup not pending");
        _removeBackup();
    }

    function getBackupState() external view returns (uint8) {
        return s_backup.state;
    }

    function getOwner() external view returns (address) {
        return s_owner;
    }

    function getBackupWallet() external view returns (address) {
        return s_backup.wallet;
    }

    function isOwner() external view returns (bool) {
        return (s_owner == msg.sender);
    }

    function isBackup() external view returns (bool) {
        return (s_backup.wallet == msg.sender);
    }

    function getBackupTimeout() external view returns (uint40) {
        return s_backup.timeout;
    }

    function getBackupTimestamp() external view returns (uint40) {
        return s_backup.timestamp;
    }

    function getBackupTimeLeft() public view returns (uint40 res) {
        unchecked {
            uint40 timestamp = getBlockTimestamp();
            if (
                s_backup.timestamp > 0 &&
                timestamp >= s_backup.timestamp &&
                s_backup.timeout > timestamp - s_backup.timestamp
            ) {
                res = s_backup.timeout - (timestamp - s_backup.timestamp);
            }
        }
    }

    function getBlockTimestamp() internal view returns (uint40) {
        // solium-disable-next-line security/no-block-members
        return uint40(block.timestamp); //safe for next 34K years
    }

    function _removeBackup() private {
        address backup = s_backup.wallet;
        if (backup != address(0)) {
            ICreator(this.creator()).removeWalletBackup(backup);
            s_backup.wallet = address(0);
        }
        if (s_backup.timeout != 0) s_backup.timeout = 0;
        if (s_backup.timestamp != 0) s_backup.timestamp = 0;
        if (s_backup.state != BACKUP_STATE_PENDING)
            s_backup.state = BACKUP_STATE_PENDING;
        emit BackupRemoved(this.creator(), s_owner, backup, s_backup.state);
    }
}
