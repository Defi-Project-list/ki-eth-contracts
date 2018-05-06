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
        require(_backupWallet != 0x0);
        emit BackupChanged(owner, backupInfo.backupWallet, _timeout);
        backupInfo.backupWallet = _backupWallet;
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
        return backupInfo.timeout;
    }

    function getBackupTimestamp() view public returns (uint64) {
        return backupInfo.timestamp;
    }

    function getBackupTimeLeft() public view returns (uint64 _res) {
        if (backupInfo.timestamp + backupInfo.timeout <= getBlockTimestamp()){
            _res = uint64(0);
        }
        else {
            _res = backupInfo.timestamp + backupInfo.timeout - getBlockTimestamp();
        }
    }

    function getBlockTimestamp() internal view returns (uint64){
        // solium-disable-next-line security/no-block-members
        return uint64(block.timestamp); //safe for next 500B years
    }

    function touch() public onlyOwner {
        emit OwnerTouched();
        backupInfo.timestamp = getBlockTimestamp();
    }



}