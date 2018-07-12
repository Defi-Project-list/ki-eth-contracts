pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./SW_StorageBase.sol";

contract SW_Storage is SW_StorageBase {

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
}
