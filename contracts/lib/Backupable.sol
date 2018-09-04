pragma solidity 0.4.24;

import "./StorageBase.sol";
import "./Storage.sol";

contract Backupable is IStorage, StorageBase, Storage {

    //event OwnerTouched          (address indexed creator, uint40 timestamp);
    event BackupChanged         (address indexed creator, address indexed owner, address indexed wallet, uint32 timeout, uint40 timestamp);
    event BackupRemoved         (address indexed creator, address indexed owner, address indexed wallet);
    event BackupRegistered      (address indexed creator, address indexed wallet);
    event BackupEnabled         (address indexed creator, address indexed wallet, uint40 timestamp);
    event BackupActivated       (address indexed creator, address indexed wallet, address indexed activator);
    event OwnershipTransferred  (address indexed creator, address indexed previousOwner, address indexed newOwner);
    event OwnershipReclaimed    (address indexed creator, address indexed owner, address indexed pendingOwner);

    modifier onlyActiveOwner () {
        require (msg.sender == this.owner() && backup.state != BACKUP_STATE_ACTIVATED, "msg.sender!=backup.owner");
        _;
    }

    modifier onlyBackup () {
        require (msg.sender == backup.wallet, "msg.sender!=backup.wallet");
        _;
    }

    function setBackup (address _wallet, uint32 _timeout) public onlyActiveOwner {
        require (_wallet != address(0), "_wallet!=address(0)");
        require (_wallet != owner, "_wallet!=owner");
        
        if (backup.wallet != _wallet) {
            if (backup.wallet != address(0)){
                ICreator(this.creator()).removeWalletBackup(backup.wallet);
            }
            backup.wallet = _wallet;
            ICreator(this.creator()).addWalletBackup(_wallet);
            if (backup.state != BACKUP_STATE_PENDING) backup.state = BACKUP_STATE_PENDING;
        }
        if (backup.timeout != _timeout) backup.timeout = _timeout;
        if (backup.state == BACKUP_STATE_ENABLED) {
            backup.timestamp = getBlockTimestamp();
        }
        emit BackupChanged (this.creator(), owner, _wallet, _timeout, backup.timestamp);
    }

    function removeBackup () public onlyOwner {
        require (backup.wallet != address(0), "backup.wallet!=address(0)");
        _removeBackup ();
    }

    function _removeBackup () private {
        emit BackupRemoved (this.creator(), owner, backup.wallet);
        if (backup.wallet != address(0)){
            ICreator(this.creator()).removeWalletBackup(backup.wallet);
            backup.wallet = address(0);
        }
        if (backup.timeout != 0) backup.timeout = 0;
        if (backup.timestamp != 0) backup.timestamp = 0;
        if (backup.state != BACKUP_STATE_PENDING) backup.state = BACKUP_STATE_PENDING;
    }

    function activateBackup () public {
        require (backup.state == BACKUP_STATE_ENABLED, "backup.state==BACKUP_STATE_ENABLED");
        require (backup.wallet != address(0), "backup.wallet!=address(0)");
        require (getBackupTimeLeft() == 0, "getBackupTimeLeft()==0");
        //require (msg.sender == tx.origin);
        emit BackupActivated (this.creator(), backup.wallet, msg.sender);
        if (backup.state != BACKUP_STATE_ACTIVATED) backup.state = BACKUP_STATE_ACTIVATED;
    }

    function getBackupState () public view returns (uint8) {
        return backup.state;
    }

    function getOwner () public view returns (address) {
        return owner;
    }

    function getBackupWallet () public view returns (address) {
        return backup.wallet;
    }

    function isOwner () external view returns (bool) {
        return (owner == msg.sender);
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
        require (backup.state == BACKUP_STATE_ACTIVATED, "backup.state==BACKUP_STATE_ACTIVATED");
        emit OwnershipTransferred (this.creator(), owner, backup.wallet);
        if (owner != backup.wallet) ICreator(this.creator()).transferWalletOwnership(backup.wallet);
        backup.wallet = address(0);
        if (backup.timeout != 0) backup.timeout = 0;
        backup.state = BACKUP_STATE_PENDING;
    }

    function reclaimOwnership () public onlyOwner {
        if (backup.state == BACKUP_STATE_ACTIVATED) backup.state = BACKUP_STATE_REGISTERED;
        emit OwnershipReclaimed (this.creator(), owner, backup.wallet);
    }

    function enable () public onlyBackup {
        require(backup.state == BACKUP_STATE_REGISTERED, "backup.state==BACKUP_STATE_REGISTERED");
        uint40 timestamp = getBlockTimestamp();
        emit BackupEnabled (this.creator(), backup.wallet, timestamp);
        backup.state = BACKUP_STATE_ENABLED;
        backup.timestamp = timestamp;
    }

    function accept () public onlyBackup {
        require(backup.state == BACKUP_STATE_PENDING, "backup.state==BACKUP_STATE_PENDING");
        emit BackupRegistered (this.creator(), backup.wallet);
        backup.state = BACKUP_STATE_REGISTERED;
    }

    function decline () public onlyBackup {
        require(backup.state == BACKUP_STATE_PENDING, "backup.state==BACKUP_STATE_PENDING");
        _removeBackup();
    }

}
