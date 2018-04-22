pragma solidity ^0.4.19;

contract  Backup {

    address public  owner;
    uint256 private cancelCount;
    
    struct BackupInfo {
        address backupWallet;  
        uint32  timeOut;
        uint32  timestamp;
    }

    BackupInfo private backupInfo; 

    modifier  OwnerOnly { 
        if (msg.sender != owner) {
            revert();
        }
        _;
    }

    function Backup() public {
        owner = msg.sender;
        backupInfo.timestamp = uint32(block.timestamp);
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

    function setBackup(address _backupWallet, uint32 _timeOut) public OwnerOnly {
        if (_backupWallet != 0x0) {
            backupInfo.backupWallet = _backupWallet;
        }
        backupInfo.timeOut = _timeOut;
        backupInfo.timestamp = uint32(block.timestamp);
    }

    function getBalnace() view public returns (uint256) {
        return address(this).balance;
    }

    function touch() public OwnerOnly {
        backupInfo.timestamp = uint32(block.timestamp);
    }

    function cancel() public {
        ++cancelCount;
        revert();
    }

    function() public payable { }
}
