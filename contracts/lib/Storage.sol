// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v1;

import "./StorageBase.sol";
import "../Trust.sol";

abstract contract Storage is IStorage {
    uint8 public constant BACKUP_STATE_PENDING = 0;
    uint8 public constant BACKUP_STATE_REGISTERED = 1;
    uint8 public constant BACKUP_STATE_ENABLED = 2;
    uint8 public constant BACKUP_STATE_ACTIVATED = 3;

    // ------------- Backup ---------
    struct Backup {
        address wallet;
        uint40 timestamp;
        uint32 timeout;
        uint8 state;
        uint16 filler;
    }

    Backup internal s_backup;
    // ------------- Generic ---------

    bytes32 internal s_uid;
    uint32 internal s_nonce;
    bytes32 public DOMAIN_SEPARATOR;
    uint256 public CHAIN_ID;

    // ------------- Trust ---------

    modifier onlyActiveState() {
        require(s_backup.state != BACKUP_STATE_ACTIVATED, "not active state");
        _;
    }

    function uid() external view returns (bytes32) {
        return s_uid;
    }
}
