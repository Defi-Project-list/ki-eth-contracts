// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v1;

import "./lib/MultiSig.sol";
import "./lib/Proxy.sol";
import "./lib/ProxyLatest.sol";

abstract contract FactoryStorage is MultiSig {
    address internal s_target;

    Proxy internal s_swProxy;
    ProxyLatest internal s_swProxyLatest;

    bytes8 public constant LATEST = bytes8("latest");

    struct Wallet {
        address addr;
        bool owner;
        uint88 debt;
    }

    struct UpgradeRequest {
        bytes8 version;
        uint256 validAt;
    }

    mapping(address => Wallet) internal s_accounts_wallet;
    mapping(address => bytes8) internal s_wallets_version;
    mapping(address => UpgradeRequest) internal s_wallets_upgrade_requests;
    mapping(bytes8 => address) internal s_versions_code;

    bytes8 internal s_production_version;
    address internal s_production_version_code;

    address internal s_production_version_oracle;
    mapping(bytes8 => address) internal s_versions_oracle;
    address internal s_operator;
    address internal s_activator;
    mapping(uint256 => uint256) internal s_nonce_group;

    bytes32 public DOMAIN_SEPARATOR;
    uint256 public CHAIN_ID;

    bool public s_frozen;
    bytes32 internal s_uid;


    // uint256 internal s_nonce;

    // storage end

    // modifier onlyProxy () {
    //     require (msg.sender == proxy, "not proxy");
    //     _;
    // }

    constructor(
        address owner1,
        address owner2,
        address owner3
    ) MultiSig(owner1, owner2, owner3) {
        // proxy = msg.sender; //in case we are using Factory directly
        s_swProxy = new Proxy();
        s_swProxyLatest = new ProxyLatest();
        s_versions_code[LATEST] = address(s_swProxyLatest);
        // s_nonce = 1;
        s_nonce_group[0] = 1;
        s_nonce_group[1] = 1;
        s_nonce_group[2] = 1;
        s_nonce_group[3] = 1;
        s_nonce_group[4] = 1;
        s_nonce_group[5] = 1;
        s_nonce_group[6] = 1;
        s_nonce_group[7] = 1;
        s_nonce_group[8] = 1;
        s_nonce_group[9] = 1;
    }

    // function migrate() public onlyProxy() {
    //     if (address(swProxy) == address(0x00)){
    //         swProxy = new Proxy();
    //     }

    //     if (address(swProxyLatest) == address(0x00)){
    //         swProxyLatest = new ProxyLatest();
    //         versions_code[LATEST] = address(swProxyLatest);
    //     }
    // }
}
