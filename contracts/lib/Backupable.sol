pragma solidity 0.4.23;

import "./Ownable.sol";

contract Backupable is Ownable {

    struct Backup {
        address wallet;
        uint64  timestamp;
        uint64  timeout;
        bool    activated;
    }

    Backup private backup;

    event BackupChanged   (address indexed owner, address indexed wallet, uint64 timeout);
    event BackupRemoved   (address indexed owner, address indexed wallet);
    event BackupActivated (address indexed wallet);
    event OwnerTouched    ();

    constructor () Ownable () public {
    }

    function setBackup (address _wallet, uint64 _timeout) public onlyOwner {
        require (_wallet != address(0));
        require (_wallet != owner);
        require (backup.activated == false);
        reclaimOwnership();
        emit BackupChanged (owner, _wallet, _timeout);
        backup.wallet = _wallet;
        backup.timeout = _timeout;
        backup.activated = false;
    }

    function removeBackup () public onlyOwner {
        require (backup.wallet != address(0));
        if (backup.activated == true) {
            reclaimOwnership ();
        }
        else {
            _touch ();
        }
        _removeBackup ();
    }

    function _removeBackup () private {
        emit BackupRemoved (owner, backup.wallet);
        backup.wallet = address(0);
        backup.timeout = 0;
        backup.activated = false;
    }

    function activateBackup () public {
        require (backup.activated == false);
        require (backup.wallet != address(0));
        require (getBackupTimeLeft() == 0);
        _transferOwnership (backup.wallet);
        emit BackupActivated (backup.wallet);
        backup.activated = true;
    }

    function backupActivated () view public returns (bool) {
        return backup.activated;
    }

    function getBackupWallet () view public returns (address) {
        return backup.wallet;
    }

    function imBackup () external view returns (bool) {
        return (backup.wallet == msg.sender);
    }

    function getBackupTimeout () view public returns (uint64) {
        return backup.timeout;
    }

    function getBackupTimestamp () view public returns (uint64) {
        return backup.timestamp;
    }

    function getBackupTimeLeft () view public returns (uint64 _res) {
        if (backup.timestamp + backup.timeout <= getBlockTimestamp()){
            _res = uint64(0);
        }
        else {
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

    function transferOwnership (address _newOwner) onlyOwner public {
        require (_newOwner != backup.wallet);
        require (backup.activated == false);
        super.transferOwnership (_newOwner);
        _touch();
    }

    function _transferOwnership (address _newOwner) internal {
        super._transferOwnership (_newOwner);
    }

    function claimOwnership () onlyPendingOwner public {
        _removeBackup ();
        super.claimOwnership ();
    }

    function reclaimOwnership () onlyOwner public {
        super.reclaimOwnership ();
        backup.activated = false;
        _touch ();
    }

}
