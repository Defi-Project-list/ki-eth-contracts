pragma solidity 0.5.16;

import "./StorageBase.sol";
import "./Storage.sol";

contract Backupable is IStorage, StorageBase, Storage {

    event BackupChanged         (address indexed creator, address indexed owner, address indexed wallet,
    uint32 timeout, uint40 timestamp, uint8 state);
    event BackupRemoved         (address indexed creator, address indexed owner, address indexed wallet, uint8 state);
    event BackupRegistered      (address indexed creator, address indexed wallet, uint8 state);
    event BackupEnabled         (address indexed creator, address indexed wallet, uint40 timestamp, uint8 state);
    event BackupActivated       (address indexed creator, address indexed wallet, address indexed activator, uint8 state);
    event OwnershipTransferred  (address indexed creator, address indexed previousOwner, address indexed newOwner, uint8 state);
    event OwnershipReclaimed    (address indexed creator, address indexed owner, address indexed pendingOwner, uint8 state);

    modifier onlyActiveOwner () {
        require (msg.sender == this.owner() && backup.state != BACKUP_STATE_ACTIVATED, "not active owner");
        _;
    }

    modifier onlyBackup () {
        require (msg.sender == backup.wallet, "not backup");
        _;
    }

    modifier eitherOwnerOrBackup () {
        require (msg.sender == _owner || msg.sender == backup.wallet, "neither owner nor backup");
        _;
    }

    function setBackup (address _wallet, uint32 _timeout) public onlyActiveOwner {
        require (_wallet != address(0), "no backup");
        require (_wallet != _owner, "backup is owner");

        if (backup.wallet != _wallet) {
            if (backup.wallet != address(0)){
                ICreator(this.creator()).removeWalletBackup(backup.wallet);
            }
            backup.wallet = _wallet;
            ICreator(this.creator()).addWalletBackup(_wallet);
            if (backup.state != BACKUP_STATE_PENDING) backup.state = BACKUP_STATE_PENDING;
            if (backup.timestamp != 0) backup.timestamp = 0;
        }
        if (backup.timeout != _timeout) backup.timeout = _timeout;
        if (backup.state == BACKUP_STATE_ENABLED) {
            backup.timestamp = getBlockTimestamp();
        }
        emit BackupChanged (this.creator(), _owner, _wallet, _timeout, backup.timestamp, backup.state);
    }

    function removeBackup () public onlyOwner {
        require (backup.wallet != address(0), "backup not exist");
        _removeBackup ();
    }

    function _removeBackup () private {
        address _backup = backup.wallet;
        if (_backup != address(0)){
            ICreator(this.creator()).removeWalletBackup(_backup);
            backup.wallet = address(0);
        }
        if (backup.timeout != 0) backup.timeout = 0;
        if (backup.timestamp != 0) backup.timestamp = 0;
        if (backup.state != BACKUP_STATE_PENDING) backup.state = BACKUP_STATE_PENDING;
        emit BackupRemoved (this.creator(), _owner, _backup, backup.state);
    }

    function activateBackup () public {
        require (backup.state == BACKUP_STATE_ENABLED, "backup not enabled");
        require (backup.wallet != address(0), "backup not exist");
        require (getBackupTimeLeft() == 0, "too early");
        //require (msg.sender == tx.origin);
        if (backup.state != BACKUP_STATE_ACTIVATED) backup.state = BACKUP_STATE_ACTIVATED;
        emit BackupActivated (this.creator(), backup.wallet, msg.sender, backup.state);
    }

    function getBackupState () public view returns (uint8) {
        return backup.state;
    }

    function getOwner () public view returns (address) {
        return _owner;
    }

    function getBackupWallet () public view returns (address) {
        return backup.wallet;
    }

    function isOwner () external view returns (bool) {
        return (_owner == msg.sender);
    }

    function isBackup () external view returns (bool) {
        return (backup.wallet == msg.sender);
    }

    function getBackupTimeout () public view returns (uint40) {
        return backup.timeout;
    }

    function getBackupTimestamp () public view returns (uint40) {
        return backup.timestamp;
    }

    function getBackupTimeLeft () public view returns (uint40 _res) {
        uint40 _timestamp = getBlockTimestamp();
        if (backup.timestamp > 0 && _timestamp >= backup.timestamp && backup.timeout > _timestamp - backup.timestamp) {
            _res = backup.timeout - (_timestamp - backup.timestamp);
        }
    }

    function getBlockTimestamp () internal view returns (uint40) {
        // solium-disable-next-line security/no-block-members
        return uint40(block.timestamp); //safe for next 34K years
    }

    function claimOwnership () public onlyBackup {
        require (backup.state == BACKUP_STATE_ACTIVATED, "backup not activated");
        backup.state = BACKUP_STATE_PENDING;
        emit OwnershipTransferred (this.creator(), _owner, backup.wallet, backup.state);
        if (_owner != backup.wallet) ICreator(this.creator()).transferWalletOwnership(backup.wallet);
        backup.wallet = address(0);
        if (backup.timeout != 0) backup.timeout = 0;
        if (backup.timestamp != 0) backup.timestamp = 0;
    }

    function reclaimOwnership () public onlyOwner {
        require (backup.state == BACKUP_STATE_ACTIVATED, "backup not activated");
        backup.state = BACKUP_STATE_REGISTERED;
        emit OwnershipReclaimed (this.creator(), _owner, backup.wallet, backup.state);
    }

    function enable () public eitherOwnerOrBackup {
        require(backup.state == BACKUP_STATE_REGISTERED, "backup not registered");
        uint40 timestamp = getBlockTimestamp();
        backup.state = BACKUP_STATE_ENABLED;
        backup.timestamp = timestamp;
        emit BackupEnabled (this.creator(), backup.wallet, timestamp, backup.state);
    }

    function accept () public onlyBackup {
        require(backup.state == BACKUP_STATE_PENDING, "backup not pending");
        backup.state = BACKUP_STATE_REGISTERED;
        emit BackupRegistered (this.creator(), backup.wallet, backup.state);
    }

    function decline () public onlyBackup {
        require(backup.state == BACKUP_STATE_PENDING, "backup not pending");
        _removeBackup();
    }

}
