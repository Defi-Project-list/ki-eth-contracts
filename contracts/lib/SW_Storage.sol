pragma solidity 0.4.24;

import "./SW_StorageBase.sol";

contract SW_Storage is SW_StorageBase, IStorage {

    // ------------- Backupable ---------
    struct Backup {
        address wallet;
        uint64  timestamp;
        uint32  timeout;
    }

    Backup internal backup;
    bool    activated;

    // ------------- Heritable ---------
    uint256 constant internal MAX_HEIRS = 8;

    struct Heir {
        address wallet;
        uint8   percent;
        bool    sent;
    }

    struct Inheritance {
        Heir[MAX_HEIRS] heirs;
        uint64  timeout;
        bool    enabled;
        bool    activated;
    }

    uint256 internal totalTransfered;
    Inheritance internal inheritance;

    modifier onlyActiveOwner () {
        require (msg.sender == owner && activated == false, "msg.sender != backup.owner");
        _;
    }

    modifier onlyBackup () {
        require (msg.sender == backup.wallet, "msg.sender != backup.wallet");
        _;
    }

    function migrate () external onlyCreator()  {
    }

}
