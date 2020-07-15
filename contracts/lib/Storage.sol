// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.6.11;

import "./StorageBase.sol";
//import "../Trust.sol";

abstract contract Storage is IStorage {

    uint8 constant public BACKUP_STATE_PENDING    = 0;
    uint8 constant public BACKUP_STATE_REGISTERED = 1;
    uint8 constant public BACKUP_STATE_ENABLED    = 2;
    uint8 constant public BACKUP_STATE_ACTIVATED  = 3;

    // ------------- Backupable ---------
    struct Backup {
        address wallet;
        uint40  timestamp;
        uint32  timeout;
        uint8   state;
        uint16  filler;
    }

    Backup internal backup;

    // ------------- Heritable ---------
    uint256 constant internal MAX_HEIRS = 8;

    struct Heir {
        address payable wallet;
        bool    sent;
        uint16  bps;
        uint72  filler;
    }

    struct Inheritance {
        Heir[MAX_HEIRS] heirs;
        uint40  timeout;
        bool    enabled;
        bool    activated;
        uint40  timestamp;
        uint16  filler;
    }

    uint256 internal totalTransfered;
    Inheritance internal inheritance;

    // ------------- Trust ---------
    //Trust internal trust;

}
