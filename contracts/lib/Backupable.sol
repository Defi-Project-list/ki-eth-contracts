pragma solidity 0.4.23;

import "./Ownable.sol";

contract Backupable is Ownable {

    struct BackupInfo {
        address backupWallet;
        uint64  timestamp;
        uint64  timeout;
    }

    BackupInfo private backupInfo;

    event BackupChanged(address indexed owner, address indexed newBackupWallet, uint64 timeOut);
    event BackupRemoved(address indexed owner, address indexed backupWallet);
    event BackupActivated(address indexed backupWallet);
    event OwnerTouched();

    constructor() public {
    }

    function setBackup(address _backupWallet, uint64 _timeout) public onlyOwner {
        if (_backupWallet != 0x0) {
            backupInfo.backupWallet = _backupWallet;
        }
        emit BackupChanged(owner, backupInfo.backupWallet, _timeout);
        backupInfo.timeout = _timeout;
        backupInfo.timestamp = getBlockTimestamp();
    }

    function removeBackup() public onlyOwner {
        require(backupInfo.backupWallet != 0x0);
        emit BackupRemoved(owner, backupInfo.backupWallet);
        backupInfo.backupWallet = 0;
        backupInfo.timeout = 0;
    }

    function getBackupWallet() view public returns (address) {
        return backupInfo.backupWallet;
    }

    function getBackupTimeout() view public returns (uint64) {
        return backupInfo.timestamp;
    }

    function getBackupTimeLeft() public view returns (uint64) {
        return (getBlockTimestamp() - backupInfo.timestamp);
    }

    function getBlockTimestamp() internal view returns (uint64){
        // solium-disable-next-line security/no-block-members
        return backupInfo.timestamp; //safe for next 500B years
    }

    function touch() public onlyOwner {
        emit OwnerTouched();
        backupInfo.timestamp = getBlockTimestamp();
    }



}
