pragma solidity ^0.4.19;

contract  Backup {

    address public  owner;
    address private backupWallet;  
    uint private    timeOut;
    uint private    timestamp;

    modifier  OwnerOnly { 
        if (msg.sender != owner) {
            revert();
        }
        _;
    }

    function Backup() public {
        owner = msg.sender;
        timestamp = block.timestamp;
    }

    function getBackupWallet() view public returns (address) {
        return backupWallet;
    }

    function getTimeOut() view public returns (uint) {
        return timeOut;
    }

    function getTimestamp() view public returns (uint) {
        return timestamp;
    }

    function setBackup(address _backupWallet, uint _timeOut) public OwnerOnly {
        if (_backupWallet != 0x0) {
            backupWallet = _backupWallet;
        }
        timeOut = _timeOut;
        timestamp = block.timestamp;
    }

    function getBalnace() view public returns (uint256) {
        return address(this).balance;
    }

    function touch() public OwnerOnly {
        timestamp = block.timestamp;
    }

    function() public payable { }
}
