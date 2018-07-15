pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/ownership/Claimable.sol";

import "./lib/SW_Proxy.sol";
import "./lib/SW_ProxyLatest.sol";

contract SW_FactoryStorage is Claimable {
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

    SW_Proxy public swProxy;
    SW_ProxyLatest public swProxyLatest;

    bytes8 public constant LATEST = bytes8("latest");

    struct SmartWallet {
        address addr;
        bool owner;
    }

    modifier onlyProxy () {
        require (msg.sender == proxy);
        _;
    }

    mapping(address => SmartWallet) internal accounts_smartwallet;
    mapping(address => bytes8) internal smartwallets_version;
    mapping(bytes8 => address) internal versions_code;

    bytes8 internal production_version;
    address internal production_version_code;

    constructor() Claimable() public {
        //swProxy = new SW_Proxy();
        //swProxyLatest = new SW_ProxyLatest();
        //versions_code[LATEST] = swProxyLatest;
    }

    function migrate() public onlyProxy() {
        if (address(swProxy) == address(0x00)){
            swProxy = new SW_Proxy();
        }

        if (address(swProxyLatest) == address(0x00)){
            swProxyLatest = new SW_ProxyLatest();
            versions_code[LATEST] = swProxyLatest;
        }
    }

    function getLatestVersion() external view returns (address) {
        return production_version_code;
    }

    function getSmartWallet(address _account) external view returns (address) {
        return accounts_smartwallet[_account].addr;
    }

}
