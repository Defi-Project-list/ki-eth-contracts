pragma solidity 0.4.23;

contract  Backup {

    address public  owner;
    uint256 private cancelCount;

    struct BackupInfo {
        address backupWallet;
        uint64  timestamp;
        uint64  timeOut;
    }

    BackupInfo private backupInfo;

    event GotMoney(address indexed from, uint256 value);

    modifier OwnerOnly {
        if (msg.sender != owner) {
            revert();
        }
        _;
    }

    modifier LogPayment {
        if (msg.value > 0) {
            emit GotMoney(msg.sender, msg.value);
        }
        _;
    }

    constructor() public {
        owner = msg.sender;
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

    function setBackup(address _backupWallet, uint64 _timeOut) public OwnerOnly {
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

    function touch() public OwnerOnly {
        // solium-disable-next-line security/no-block-members
        backupInfo.timestamp = uint64(block.timestamp);
    }

    function cancel() public {
        ++cancelCount;
        revert();
    }

    function() payable LogPayment public {
    }
}
