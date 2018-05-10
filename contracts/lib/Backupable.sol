pragma solidity 0.4.23;

import "./Ownable.sol";

contract Backupable is Ownable {

    struct BackupInfo {
        address backupWallet;
        uint64  timestamp;
        uint64  timeout;
    }

    BackupInfo private backupInfo;

    event BackupChanged   (address indexed owner, address indexed newBackupWallet, uint64 timeOut);
    event BackupRemoved   (address indexed owner, address indexed backupWallet);
    event BackupActivated (address indexed backupWallet);
    event OwnerTouched();

    constructor() public {
    }

    function setBackup (address _backupWallet, uint64 _timeout) public onlyOwner {
        require (_backupWallet != address(0));
        emit BackupChanged (owner, backupInfo.backupWallet, _timeout);
        backupInfo.backupWallet = _backupWallet;
        backupInfo.timeout = _timeout;
        backupInfo.timestamp = getBlockTimestamp();
    }

    function removeBackup() public onlyOwner {
        require (backupInfo.backupWallet != address(0));
        emit BackupRemoved (owner, backupInfo.backupWallet);
        _removeBackup();
    }

    function _removeBackup() private {
        backupInfo.backupWallet = address(0);
        backupInfo.timeout = 0;
    }

    function activateBackup () public {
        require (backupInfo.backupWallet != address(0));
        require (getBackupTimeLeft() == 0);
        emit BackupActivated (backupInfo.backupWallet);
        _transferOwnership (backupInfo.backupWallet);
    }

    function getBackupWallet () view public returns (address) {
        return backupInfo.backupWallet;
    }

    function getBackupTimeout () view public returns (uint64) {
        return backupInfo.timeout;
    }

    function getBackupTimestamp () view public returns (uint64) {
        return backupInfo.timestamp;
    }

    function getBackupTimeLeft () view public returns (uint64 _res) {
        if (backupInfo.timestamp + backupInfo.timeout <= getBlockTimestamp()){
            _res = uint64(0);
        }
        else {
            _res = backupInfo.timestamp + backupInfo.timeout - getBlockTimestamp();
        }
    }

    function getBlockTimestamp () private view returns (uint64){
        // solium-disable-next-line security/no-block-members
        return uint64(block.timestamp); //safe for next 500B years
    }

    function touch() public onlyOwner {
        emit OwnerTouched();
        backupInfo.timestamp = getBlockTimestamp();
    }

    function transferOwnership(address _newOwner) onlyOwner public {
        _transferOwnership(_newOwner);
    }

    function _transferOwnership(address _newOwner) internal {
        touch();
        super._transferOwnership(_newOwner);
    }

    function claimOwnership() onlyPendingOwner public {
        _removeBackup();
        super.claimOwnership();
    }

    function reClaimOwnership() onlyOwner public {
        touch();
        super.reClaimOwnership();
    }

}
