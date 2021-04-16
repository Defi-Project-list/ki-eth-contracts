// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v1;

import "./lib/MultiSig.sol";
import "./lib/Proxy.sol";
import "./lib/ProxyLatest.sol";

abstract contract FactoryStorage is MultiSig {
    address public target;
    //    address public proxy;

    Proxy public swProxy;
    ProxyLatest public swProxyLatest;

    bytes8 public constant LATEST = bytes8("latest");

    struct Wallet {
        address addr;
        bool owner;
    }

    mapping(address => Wallet) internal accounts_wallet;
    mapping(address => bytes8) internal wallets_version;
    mapping(bytes8 => address) internal versions_code;

    bytes8 internal production_version;
    address internal production_version_code;

    address internal production_version_oracle;
    mapping(bytes8 => address) internal versions_oracle;
    address internal _operator;
    address internal _activator;
    mapping(uint256 => uint256) internal s_nonce_group;
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
        swProxy = new Proxy();
        swProxyLatest = new ProxyLatest();
        versions_code[LATEST] = address(swProxyLatest);
        // s_nonce = 1;
        s_nonce_group[1] = 1;
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
