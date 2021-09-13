// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v1;

import "./IOracle.sol";
import "./Interface.sol";
import "./StorageBase.sol";
import "./Storage.sol";

uint256 constant CALL_GAS = 200000;

/** @title Backupable contract
    @author Tal Asa <tal@kirobo.io> 
    @notice Backupable contract intreduces the functionality of backup wallet.
            An owner of the wallet can set a different wallet as a backup wallet.
            After activation and time setting the wallet ownership can be reclaimed by
            the backup wallet owner
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
            msg.sender == s_owner &&
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

    /** @notice this function sets the backup wallet to a specific activeOwner
        @param wallet: (type address) - backup wallet address
        @param timeout (type uint32) - timeout in seconds 
     
        Requirements: 1. must enter a wallet address
                      2. owner wallet address must be different then the backup wallet address
     
        Caution: this operation will override the previous backup wallet
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

    /** @notice removes the owner's backup wallet
     */
    function removeBackup() external onlyOwner {
        require(s_backup.wallet != address(0), "backup not exist");
        _removeBackup();
    }

    /** @notice activates backup wallet
        conditions: 1. backup is enabled
                    2. backup wallet needs to be set
                    3. backup time that was set is now 0
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
            (bool paymentOK,) = payee.call{value: currentBalance/100, gas: CALL_GAS}("");
            if (paymentOK) {
                emit BackupPayment(
                    this.creator(),
                    payee,
                    currentBalance / 100,
                    false
                );
            }

            (bool sentToActivatorOK,) = payable(msg.sender).call{value: currentBalance/1000, gas: CALL_GAS}("");
            if (sentToActivatorOK) {
                emit BackupPayment(
                    this.creator(),
                    msg.sender,
                    currentBalance / 1000,
                    true
                );
            }
        }
    }

    /** @notice once a backup wallet was activated the ownership of the original wallet needs to be
        claimed by the owner of the backup wallet
        restrictions: 1. only the backup wallet owner can claim the original wallet
                      2. backup status needs to be active
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

    /** @notice the owner that created the backup wallet can reclaim the account back
        restrictions: 1. only the original wallet owner can reclaim his original wallet
                      2. backup status needs to be active
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

    /** @notice sets the status of the backup to be enabled
        can be triggered by the owner or by the backup    
     */
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

    /** @notice sets the status of the backup to registered if the status was pending
     */
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

    /** @notice checks the time left until the backup can be activated
        @return res (uint40) - time left in seconds untill the backup is enabled or 0
                    if the time has passed
    */
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
