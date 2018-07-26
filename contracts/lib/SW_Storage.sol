pragma solidity 0.4.24;

import "./SW_StorageBase.sol";

contract SW_Storage is SW_StorageBase, IStorage {

    uint8 constant internal BACKUP_STATE_PENDING   = 0;
    uint8 constant internal BACKUP_STATE_REGISTERED  = 1;
    uint8 constant internal BACKUP_STATE_ACTIVATED = 2;

    // ------------- Backupable ---------
    struct Backup {
        address wallet;
        uint40  timestamp;
        uint32  timeout;        
        uint8   state;
    }

    Backup internal backup;

    // ------------- Heritable ---------
    uint256 constant internal MAX_HEIRS = 8;

    struct Heir {
        address wallet;
        uint8   percent;
        bool    sent;
    }

    struct Inheritance {
        Heir[MAX_HEIRS] heirs;
        uint40  timeout;
        bool    enabled;
        bool    activated;
    }

    uint256 internal totalTransfered;
    Inheritance internal inheritance;

    modifier onlyActiveOwner () {
        require (msg.sender == owner && backup.state != BACKUP_STATE_ACTIVATED, "msg.sender != backup.owner");
        _;
    }

    modifier onlyBackup () {
        require (msg.sender == backup.wallet, "msg.sender != backup.wallet");
        _;
    }

    function migrate () external onlyCreator()  {
    }

}
