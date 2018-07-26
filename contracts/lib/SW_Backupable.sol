pragma solidity 0.4.24;

import "./SW_Storage.sol";

contract SW_Backupable is SW_Storage {

    event OwnerTouched          ();
    event BackupChanged         (address indexed owner, address indexed wallet, uint32 timeout);
    event BackupRemoved         (address indexed owner, address indexed wallet);
    event BackupActivated       (address indexed wallet);
    event OwnershipTransferred  (address indexed previousOwner, address indexed newOwner);

    function setBackup (address _wallet, uint32 _timeout) public onlyOwner {
        require (_wallet != address(0));
        require (_wallet != owner);
        require (backup.state != BACKUP_STATE_ACTIVATED);
        reclaimOwnership();
        emit BackupChanged (owner, _wallet, _timeout);
        if (backup.wallet != _wallet) {
            if (backup.wallet != address(0)){
                ICreator(this.creator()).removeBackup(backup.wallet);
            }
            backup.wallet = _wallet;
            ICreator(this.creator()).addBackup(_wallet);
        }
        if (backup.timeout != _timeout) backup.timeout = _timeout;
    }

    function setTimeout (uint32 _timeout) public onlyOwner {
        require (backup.wallet != address(0));
        require (backup.state != BACKUP_STATE_ACTIVATED);
        _touch ();
        if (backup.timeout != _timeout) backup.timeout = _timeout;
    }

    function removeBackup () public onlyOwner {
        require (backup.wallet != address(0));
        if (backup.state == BACKUP_STATE_ACTIVATED) {
            reclaimOwnership ();
        }
        else {
            _touch ();
        }
        _removeBackup ();
    }

    function _removeBackup () private {
        emit BackupRemoved (owner, backup.wallet);
        if (backup.wallet != address(0)){
            ICreator(this.creator()).removeBackup(backup.wallet);
            backup.wallet = address(0);
        }
        if (backup.timeout != 0) backup.timeout = 0;
        if (backup.state != BACKUP_STATE_PENDING) backup.state = BACKUP_STATE_PENDING;
    }

    function activateBackup () public {
        require (backup.state == BACKUP_STATE_REGISTERED);
        require (backup.wallet != address(0));
        require (getBackupTimeLeft() == 0);
        emit BackupActivated (backup.wallet);
        if (backup.state != BACKUP_STATE_ACTIVATED) backup.state = BACKUP_STATE_ACTIVATED;
    }

    function isBackupActivated () view public returns (bool) {
        return backup.state == BACKUP_STATE_ACTIVATED;
    }

    function getOwner () view public returns (address) {
        return owner;
    }

    function getBackupWallet () view public returns (address) {
        return backup.wallet;
    }

    function isOwner () external view returns (bool) {
        return (owner == msg.sender);
    }

    function isBackup () external view returns (bool) {
        return (backup.wallet == msg.sender);
    }

    function getBackupTimeout () view public returns (uint40) {
        return backup.timeout;
    }

    function getBackupTimestamp () view public returns (uint40) {
        return backup.timestamp;
    }

    function getBackupTimeLeft () view public returns (uint40 _res) {
        if (backup.timestamp + backup.timeout > getBlockTimestamp()){
            _res = backup.timestamp + backup.timeout - getBlockTimestamp();
        }
    }

    function getTouchTimestamp () internal view returns (uint40) {
        return uint40(backup.timestamp);
    }

    function getBlockTimestamp () internal view returns (uint40) {
        // solium-disable-next-line security/no-block-members
        return uint40(block.timestamp); //safe for next 34K years
    }

    function touch () onlyOwner public {
        _touch();
    }

    function _touch() internal {
        emit OwnerTouched();
        backup.timestamp = getBlockTimestamp();
    }

    function claimOwnership () onlyBackup public {
        require (backup.state == BACKUP_STATE_ACTIVATED);
        emit OwnershipTransferred (owner, backup.wallet);
        if (owner != backup.wallet) ICreator(this.creator()).changeOwner(backup.wallet);
        _removeBackup ();
    }

    function reclaimOwnership () onlyOwner public {
        if (backup.state == BACKUP_STATE_ACTIVATED) backup.state = BACKUP_STATE_REGISTERED;
        _touch ();
    }

    function accept () onlyBackup public {
        require(backup.state == BACKUP_STATE_PENDING);
        backup.state = BACKUP_STATE_REGISTERED;
    }

    function decline () onlyBackup public {
        require(backup.state == BACKUP_STATE_PENDING);
        _removeBackup();
    }

}
