pragma solidity 0.4.24;

contract Backupable {

    struct Backup {
        address wallet;
        uint64  timestamp;
        uint32  timeout;
    }

    struct Self {
        address owner;
        bool    activated;
    }

    Backup private backup;
    Self   private self;

    event OwnerTouched          ();
    event BackupChanged         (address indexed owner, address indexed wallet, uint32 timeout);
    event BackupRemoved         (address indexed owner, address indexed wallet);
    event BackupActivated       (address indexed wallet);
    event OwnershipTransferred  (address indexed previousOwner, address indexed newOwner);

    constructor () public {
        self.owner = msg.sender;
    }

    modifier onlyOwner () {
        require (msg.sender == self.owner, "msg.sender != backup.owner");
        _;
    }

    modifier onlyActiveOwner () {
        require (msg.sender == self.owner && self.activated == false, "msg.sender != backup.owner");
        _;
    }

    modifier onlyBackup () {
        require (msg.sender == backup.wallet, "msg.sender != backup.wallet");
        _;
    }

    function setBackup (address _wallet, uint32 _timeout) public onlyOwner {
        require (_wallet != address(0));
        require (_wallet != self.owner);
        require (self.activated == false);
        reclaimOwnership();
        emit BackupChanged (self.owner, _wallet, _timeout);
        if (backup.wallet != _wallet)   backup.wallet = _wallet;
        if (backup.timeout != _timeout) backup.timeout = _timeout;
        if (self.activated != false)    self.activated = false;
    }

    function removeBackup () public onlyOwner {
        require (backup.wallet != address(0));
        if (self.activated == true) {
            reclaimOwnership ();
        }
        else {
            _touch ();
        }
        _removeBackup ();
    }

    function _removeBackup () private {
        emit BackupRemoved (self.owner, backup.wallet);
        if (backup.wallet != address(0)) backup.wallet = address(0);
        if (backup.timeout != 0) backup.timeout = 0;
        if (self.activated != false) self.activated = false;
    }

    function activateBackup () public {
        require (self.activated == false);
        require (backup.wallet != address(0));
        require (getBackupTimeLeft() == 0);
        emit BackupActivated (backup.wallet);
        if (self.activated != true) self.activated = true;
    }

    function isBackupActivated () view public returns (bool) {
        return self.activated;
    }

    function getOwner () view public returns (address) {
        return self.owner;
    }

    function getBackupWallet () view public returns (address) {
        return backup.wallet;
    }

    function isOwner () external view returns (bool) {
        return (self.owner == msg.sender);
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
        require (self.activated == true);
        emit OwnershipTransferred (self.owner, backup.wallet);
        if (self.owner != backup.wallet) self.owner = backup.wallet;
        _removeBackup ();
    }

    function reclaimOwnership () onlyOwner public {
        if (self.activated != false) self.activated = false;
        _touch ();
    }

}
