pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/ownership/Claimable.sol";

import "./lib/Proxy.sol";
import "./lib/ProxyLatest.sol";

contract FactoryStorage is Claimable {
    uint256 internal dummy1;
    uint256 internal dummy2;
    uint256 internal dummy3;
    uint256 internal dummy4;
    uint256 internal dummy5;
    uint256 internal dummy6;
    uint256 internal dummy7;
    uint256 internal dummy8;

    address public target;
    address public proxy;

    Proxy public swProxy;
    ProxyLatest public swProxyLatest;

    bytes8 public constant LATEST = bytes8("latest");

    struct Wallet {
        address addr;
        bool owner;
    }

    modifier onlyProxy () {
        require (msg.sender == proxy);
        _;
    }

    mapping(address => Wallet) internal accounts_wallet;
    mapping(address => bytes8) internal wallets_version;
    mapping(bytes8 => address) internal versions_code;

    bytes8 internal production_version;
    address internal production_version_code;

    constructor() Claimable() public {
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

    function getLatestVersion() external view returns (address) {
        return production_version_code;
    }

    function getWallet(address _account) external view returns (address) {
        return accounts_wallet[_account].addr;
    }

}
