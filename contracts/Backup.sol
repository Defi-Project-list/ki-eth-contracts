pragma solidity 0.4.23;

import "./lib/Heritable.sol";

contract Backup is Heritable {

    uint256 private cancelCount;

    struct BackupInfo {
        address backupWallet;
        uint64  timestamp;
        uint64  timeOut;
    }

    BackupInfo private backupInfo;

    event GotMoney(address indexed from, uint256 value);

    modifier logPayment {
        if (msg.value > 0) {
            emit GotMoney(msg.sender, msg.value);
        }
        _;
    }

    constructor() Heritable(1000) public {
        // solium-disable-next-line security/no-block-members
        backupInfo.timestamp = uint64(block.timestamp);
    }

    function getBackupWallet() view public returns (address) {
        return backupInfo.backupWallet;
    }

    function getTimeOut() view public returns (uint) {
        return backupInfo.timeOut;
    }

    function getTimestamp() view public returns (uint) {
        return backupInfo.timestamp;
    }

    function setBackup(address _backupWallet, uint64 _timeOut) public onlyOwner {
        if (_backupWallet != 0x0) {
            backupInfo.backupWallet = _backupWallet;
        }
        backupInfo.timeOut = _timeOut;
        // solium-disable-next-line security/no-block-members
        backupInfo.timestamp = uint64(block.timestamp); //safe for next 500B years
    }

    function getBalnace() view public returns (uint256) {
        return address(this).balance;
    }

    function touch() public onlyOwner {
        // solium-disable-next-line security/no-block-members
        backupInfo.timestamp = uint64(block.timestamp);
    }

    function cancel() public {
        ++cancelCount;
        revert();
    }

    function() payable logPayment public {
    }
}
