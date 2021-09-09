// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v2;

import "./FactoryStorage.sol";
import "./lib/IOracle.sol";

/** @title Factory contract 
    @author Tal Asa <tal@kirobo.io> 
    @notice Factory contract - defines functions that are used by all related contracts
 */
contract Factory is FactoryStorage {
    bytes32 public constant BATCH_MULTI_SIG_CALL_TYPEHASH =
        keccak256(
            "BatchMultiSigCall(Limits limits,Transaction transaction)Limits(uint256 sessionId)Transaction(address signer,address to,uint256 value,uint32 gasLimit,uint16 flags,bytes data)"
        );

    bytes32 public constant BATCH_MULTI_SIG_CALL_LIMITS_TYPEHASH =
        keccak256("Limits(uint256 sessionId)");

    bytes32 public constant BATCH_MULTI_SIG_CALL_TRANSACTION_TYPEHASH =
        keccak256(
            "Transaction(address signer,address to,uint256 value,uint32 gasLimit,uint16 flags,bytes data)"
        );

    event WalletCreated(
        address indexed wallet,
        bytes8 indexed version,
        address indexed owner
    );

    event WalletUpgraded(address indexed wallet, bytes8 indexed version);

    event WalletUpgradeRequested(
        address indexed wallet,
        bytes8 indexed version
    );

    event WalletUpgradeDismissed(
        address indexed wallet,
        bytes8 indexed version
    );

    event WalletConfigurationRestored(
        address indexed wallet,
        bytes8 indexed version,
        address indexed owner
    );

    event WalletOwnershipRestored(
        address indexed wallet,
        address indexed owner
    );

    event WalletVersionRestored(
        address indexed wallet,
        bytes8 indexed version,
        address indexed owner
    );

    event WalletOwnershipTransfered(
        address indexed wallet,
        address indexed owner,
        address indexed newOwner
    );

    event WalletBakcupCreated(
        address indexed wallet,
        address indexed owner,
        address indexed backup
    );

    event WalletBackupRemoved(address indexed wallet, address indexed backup);

    event VersionAdded(
        bytes8 indexed version,
        address indexed code,
        address indexed oracle
    );

    event VersionDeployed(
        bytes8 indexed version,
        address indexed code,
        address indexed oracle
    );

    event BatchMultiSigCallPackedFailed(
        address indexed wallet,
        uint256 nonce,
        uint256 index,
        uint256 innerIndex
    );
    event BatchTransfered(uint256 indexed mode, uint256 block, uint256 nonce);

    constructor(
        // address owner1,
        // address owner2,
        // address owner3
    ) FactoryStorage() {} // owner1, owner2, owner3) {}

    // receive() external payable {
    //     require(false, "Factory: not aceepting ether");
    // }


    /** @notice transferWalletOwnership - the function transfers the ownership of the wallet 
                to the newOwner in the input param
        @param newOwner (address) - address of the new owner that the ownership will move to
     */
    function transferWalletOwnership(address newOwner) external {
        address curOwner = IProxy(msg.sender).owner();
        Wallet storage sp_sw = s_accounts_wallet[curOwner];
        require(msg.sender == sp_sw.addr, "from: no wallet");
        require(sp_sw.owner, "from: not wallet owner");
        Wallet storage sp_sw2 = s_accounts_wallet[newOwner];
        require(msg.sender == sp_sw2.addr, "to: not same wallet as from");
        require(sp_sw2.owner == false, "to: wallet owner");
        sp_sw2.owner = true;
        sp_sw.owner = false;
        sp_sw.addr = address(0);
        IProxy(msg.sender).init(newOwner, address(0));
        emit WalletOwnershipTransfered(sp_sw.addr, curOwner, newOwner);
    }

    /** @notice addWalletBackup - adds a backup to the current wallet owner 
        @param backup (address) - the address of the backup wallet
     */
    function addWalletBackup(address backup) external {
        require(backup != address(0), "input backup walled is empty");
        Wallet storage sp_sw = s_accounts_wallet[backup];
        require(sp_sw.addr == address(0), "backup has no wallet");
        require(sp_sw.owner == false, "backup is wallet owner");
        address owner = IProxy(msg.sender).owner();
        Wallet storage sp_sw_owner = s_accounts_wallet[owner];
        require(msg.sender == sp_sw_owner.addr, "not wallet");
        require(sp_sw_owner.owner, "no wallet owner");
        sp_sw.addr = msg.sender;
        emit WalletBakcupCreated(sp_sw.addr, owner, backup);
    }

    /** @notice removeWalletBackup - removes a specific address from being the owners backup
        @param backup (address) - the address of the backup wallet
     */
    function removeWalletBackup(address backup) external {
        require(backup != address(0), "no backup");
        Wallet storage sp_sw = s_accounts_wallet[backup];
        require(sp_sw.addr == msg.sender, "not wallet");
        require(sp_sw.owner == false, "wallet backup not exist");
        sp_sw.addr = address(0);
        emit WalletBackupRemoved(sp_sw.addr, backup);
    }

    /** @notice upgradeWalletRequest - lets the owner of the wallet an option to upgrade his wallet version
        @param version (bytes8) - version number
    */
    function upgradeWalletRequest(bytes8 version) external {
        address code = s_versions_code[version];
        require(code != address(0), "no version code");
        address owner = IProxy(msg.sender).owner();
        Wallet storage sp_sw = s_accounts_wallet[owner];
        require(
            msg.sender == sp_sw.addr && sp_sw.owner,
            "sender is not wallet owner"
        );
        s_wallets_upgrade_requests[sp_sw.addr] = UpgradeRequest({
            version: version,
            validAt: block.timestamp + 48 hours
        });
        emit WalletUpgradeRequested(sp_sw.addr, version);
    }

    /** @notice upgradeWalletDismiss - dismiss the request for wallet upgrade
     */
    function upgradeWalletDismiss() external {
        address owner = IProxy(msg.sender).owner();
        Wallet storage sp_sw = s_accounts_wallet[owner];
        require(
            msg.sender == sp_sw.addr && sp_sw.owner,
            "sender is not wallet owner"
        );
        UpgradeRequest storage sp_upgradeRequest = s_wallets_upgrade_requests[
            sp_sw.addr
        ];
        require(sp_upgradeRequest.validAt > 0, "request not exsist");
        sp_upgradeRequest.validAt = 0;
        emit WalletUpgradeDismissed(sp_sw.addr, sp_upgradeRequest.version);
    }

    /** @notice upgradeWalletExecute - upgrages the wallet version
     */
    function upgradeWalletExecute() external {
        address owner = IProxy(msg.sender).owner();
        Wallet storage sp_sw = s_accounts_wallet[owner];
        require(
            msg.sender == sp_sw.addr && sp_sw.owner,
            "sender is not wallet owner"
        );
        UpgradeRequest storage sp_upgradeRequest = s_wallets_upgrade_requests[
            sp_sw.addr
        ];
        require(sp_upgradeRequest.validAt > 0, "request not exsist");
        require(sp_upgradeRequest.validAt <= block.timestamp, "too early");
        bytes8 version = sp_upgradeRequest.version;
        s_wallets_version[sp_sw.addr] = version;
        IProxy(msg.sender).init(owner, s_versions_code[version]);
        IStorage(msg.sender).migrate();
        emit WalletUpgraded(sp_sw.addr, version);
    }

    /** @notice addVersion - add a specific version
        @param target(address)
        @param targetOracle(address)
     */
    function addVersion(address target, address targetOracle)
        external
        onlyOwner()
    {
        require(target != address(0), "no version");
        require(targetOracle != address(0), "no oracle version");
        require(
            IOracle(targetOracle).initialized() != false,
            "oracle not initialized"
        );
        bytes8 version = IStorage(target).version();
        require(
            IOracle(targetOracle).version() == version,
            "version mistmatch"
        );
        address code = s_versions_code[version];
        require(code == address(0), "version exists");
        require(s_versions_oracle[version] == address(0), "oracle exists");
        s_versions_code[version] = target;
        s_versions_oracle[version] = targetOracle;
        emit VersionAdded(version, code, targetOracle);
    }

    /** @notice deployVersion - deployment of a specific version to the system 
        @param version(bytes8) - the version to deploy
    */
    function deployVersion(bytes8 version) external onlyOwner() {
        address code = s_versions_code[version];
        require(code != address(0), "version not exist");
        address oracleAddress = s_versions_oracle[version];
        require(oracleAddress != address(0), "oracle not exist");
        s_production_version = version;
        s_production_version_code = code;
        s_production_version_oracle = oracleAddress;
        emit VersionDeployed(version, code, oracleAddress);
    }

    function restoreWalletConfiguration() external {
        Wallet storage sp_sw = s_accounts_wallet[msg.sender];
        require(sp_sw.addr != address(0), "no wallet");
        require(sp_sw.owner, "not wallet owner");
        bytes8 version = s_wallets_version[sp_sw.addr];
        if (version == LATEST) {
            version = s_production_version;
        }
        address code = s_versions_code[version];
        require(code != address(0), "version not exist");
        IProxy(sp_sw.addr).init(msg.sender, code);
        emit WalletConfigurationRestored(sp_sw.addr, version, msg.sender);
    }

    function restoreWalletOwnership() external {
        Wallet storage sp_sw = s_accounts_wallet[msg.sender];
        require(sp_sw.addr != address(0), "no wallet");
        require(sp_sw.owner, "not wallet owner");

        IProxy(sp_sw.addr).init(msg.sender, address(0));
        emit WalletOwnershipRestored(sp_sw.addr, msg.sender);
    }

    function restoreWalletVersion() external {
        Wallet storage sp_sw = s_accounts_wallet[msg.sender];
        require(sp_sw.addr != address(0), "no wallet");
        require(sp_sw.owner, "not wallet owner");

        bytes8 version = s_wallets_version[sp_sw.addr];
        if (version == LATEST) {
            version = s_production_version;
        }
        address code = s_versions_code[version];
        require(code != address(0), "no version");
        IProxy(sp_sw.addr).init(address(0), code);
        emit WalletVersionRestored(sp_sw.addr, version, msg.sender);
    }

    function getLatestVersion() external view returns (address) {
        return s_production_version_code;
    }

    function getWallet(address account) external view returns (address) {
        return s_accounts_wallet[account].addr;
    }

    function getWalletDebt(address account) external view returns (uint88) {
        return s_accounts_wallet[account].debt;
    }

    /** @notice createWallet - create a new wallet
        @param autoMode(bool) - if true: sets the wallet with the latest version
                                if false: sets the wallet with the production version
        @return address
    */
    function createWallet(bool autoMode) external returns (address) {
        require(address(s_swProxy) != address(0), "no proxy");
        require(s_production_version_code != address(0), "no prod version"); //Must be here - ProxyLatest also needs it.
        Wallet storage sp_sw = s_accounts_wallet[msg.sender];
        if (sp_sw.addr == address(0)) {
            sp_sw.addr = _createWallet(address(this), address(s_swProxy));
            require(sp_sw.addr != address(0), "wallet not created");
            sp_sw.owner = true;
            if (autoMode) {
                require(
                    address(s_swProxyLatest) != address(0),
                    "no auto version"
                );
                require(
                    s_versions_code[LATEST] == address(s_swProxyLatest),
                    "incorrect auto version"
                );
                s_wallets_version[sp_sw.addr] = LATEST;
                IProxy(sp_sw.addr).init(msg.sender, address(s_swProxyLatest));
                IStorage(sp_sw.addr).migrate();
                emit WalletCreated(sp_sw.addr, LATEST, msg.sender);
            } else {
                s_wallets_version[sp_sw.addr] = s_production_version;
                IProxy(sp_sw.addr).init(msg.sender, s_production_version_code);
                IStorage(sp_sw.addr).migrate();
                emit WalletCreated(
                    sp_sw.addr,
                    s_production_version,
                    msg.sender
                );
            }
        }
        return sp_sw.addr;
    }

    function oracle() external view returns (address oracleAddress) {
        bytes8 version = s_wallets_version[msg.sender];
        if (version == LATEST) {
            version = s_production_version;
        }
        oracleAddress = s_versions_oracle[version];
    }

    // function setActivator(address newActivator) external onlyOwner() {
    //     s_activator = newActivator;
    // }

    // function setLocalEns(string calldata ens, address dest)
    //     external
    //     onlyOwner()
    // {
    //     s_local_ens[keccak256(abi.encodePacked("@", ens))] = dest;
    // }


    /** @notice _createWallet - private function that  */
    function _createWallet(address creator, address target)
        private
        returns (address result)
    {
        bytes memory code
         = hex"60998061000d6000396000f30036601657341560145734602052336001602080a25b005b6000805260046000601c376302d05d3f6000511415604b5773dadadadadadadadadadadadadadadadadadadada602052602080f35b366000803760008036600073bebebebebebebebebebebebebebebebebebebebe5af415608f57341560855734602052600051336002602080a35b3d6000803e3d6000f35b3d6000803e3d6000fd"; //log3-event-ids-address-funcid-opt (-2,-2) (min: 22440)
        bytes20 creatorBytes = bytes20(creator);
        bytes20 targetBytes = bytes20(target);
        for (uint256 i = 0; i < 20; i++) {
            code[61 + i] = creatorBytes[i];
            code[101 + i] = targetBytes[i];
        }
        assembly {
            result := create(0, add(code, 0x20), mload(code))
        }
    }
}
