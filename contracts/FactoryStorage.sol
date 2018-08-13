pragma solidity 0.4.24;

import "./lib/Proxy.sol";
import "./lib/ProxyLatest.sol";

contract FactoryStorage {
    address public owner;
    address public pendingOwner;
    address public target;
    address public proxy;

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


    // storage end

    modifier onlyProxy () {
        require (msg.sender == proxy);
        _;
    }

     modifier onlyOwner () {
        require (msg.sender == owner);
        _;
    }

    constructor() public {
        owner = msg.sender;
        swProxy = new Proxy();
        swProxyLatest = new ProxyLatest();
        versions_code[LATEST] = swProxyLatest;
    }

    function migrate() public onlyProxy() {
        if (address(swProxy) == address(0x00)){
            swProxy = new Proxy();
        }

        if (address(swProxyLatest) == address(0x00)){
            swProxyLatest = new ProxyLatest();
            versions_code[LATEST] = swProxyLatest;
        }
    }

}
