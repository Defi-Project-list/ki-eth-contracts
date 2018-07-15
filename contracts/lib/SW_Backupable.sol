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
        require (activated == false);
        reclaimOwnership();
        emit BackupChanged (owner, _wallet, _timeout);
        if (backup.wallet != _wallet) {
            backup.wallet = _wallet;
            ICreator(this.creator()).addBackup(_wallet);
        }
        if (backup.timeout != _timeout) backup.timeout = _timeout;
        if (activated != false)    activated = false;
    }

    function removeBackup () public onlyOwner {
        require (backup.wallet != address(0));
        if (activated == true) {
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
            backup.wallet = address(0);
            ICreator(this.creator()).removeBackup(backup.wallet);
        }
        if (backup.timeout != 0) backup.timeout = 0;
        if (activated != false) activated = false;
    }

    function activateBackup () public {
        require (activated == false);
        require (backup.wallet != address(0));
        require (getBackupTimeLeft() == 0);
        emit BackupActivated (backup.wallet);
        if (activated != true) activated = true;
    }

    function isBackupActivated () view public returns (bool) {
        return activated;
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

    function getBackupTimeout () view public returns (uint64) {
        return backup.timeout;
    }

    function getBackupTimestamp () view public returns (uint64) {
        return backup.timestamp;
    }

    function getBackupTimeLeft () view public returns (uint64 _res) {
        if (backup.timestamp + backup.timeout > getBlockTimestamp()){
            _res = backup.timestamp + backup.timeout - getBlockTimestamp();
        }
    }

    function getTouchTimestamp () internal view returns (uint64) {
        return uint64(backup.timestamp);
    }

    function getBlockTimestamp () internal view returns (uint64) {
        // solium-disable-next-line security/no-block-members
        return uint64(block.timestamp); //safe for next 500B years
    }

    function touch () onlyOwner public {
        _touch();
    }

    function _touch() internal {
        emit OwnerTouched();
        backup.timestamp = getBlockTimestamp();
    }

    function claimOwnership () onlyBackup public {
        require (activated == true);
        emit OwnershipTransferred (owner, backup.wallet);
        if (owner != backup.wallet) ICreator(this.creator()).changeOwner(backup.wallet);
        _removeBackup ();
    }

    function reclaimOwnership () onlyOwner public {
        if (activated != false) activated = false;
        _touch ();
    }

}
