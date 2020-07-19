'use strict';

const Factory = artifacts.require("Factory");
const truffleAssert = require('truffle-assertions');

const mlog = require('mocha-logger');
const { ZERO_ADDRESS, ZERO_BYTES32, ZERO_BN } = require('./lib/consts');
const {
  assertRevert,
  assertInvalidOpcode,
  assertPayable,
  assertFunction,
  assetEvent_getArgs
} = require('./lib/asserts');

const utils = require('./lib/utils');

module.exports = (contractClass, contractName, timeUnitInSeconds=1) => {

contract(contractName, async accounts => {
  let instance;

  const factoryOwner = accounts[0];
  const owner = accounts[1];
  const user1 = accounts[2];
  const user2 = accounts[3];

  let blockTimestamp = '0';

  before('checking constants', async () => {
      assert(typeof owner == 'string', 'owner should be string');
      assert(typeof user1 == 'string', 'user1 should be string');
      assert(typeof user2 == 'string', 'user2 should be string');
  });

  before('setup contract for the test', async () => {
	  if (contractClass.new instanceof Function) {
      instance = await contractClass.new({ from: owner, nonce: await web3.eth.getTransactionCount(owner)});
	  }
	  else {
      instance = await contractClass(factoryOwner, owner, user1, user2);
	  }

    mlog.log('web3     ', web3.version);
    mlog.log('contract ', instance.address);
    mlog.log('owner    ', owner);
    mlog.log('user1    ', user1);
    mlog.log('user2    ', user2);
  });

  it('constructor: owner should be the contract creator', async () => {
    //const contractOwner = await instance.owner.call();
    //assert.equal(contractOwner, owner);
    const isOwner = await instance.isOwner.call({from: owner});
    assert.equal(isOwner, true);
  });

  it('constructor: backupInfo should be empty', async () => {
    const backupWallet = await instance.getBackupWallet();
    const backupTimeout = await instance.getBackupTimeout();
    const backupTimestamp = await instance.getBackupTimestamp();
    const backupActivated = await utils.isBackupActivated(instance);

    assert.equal(backupWallet, ZERO_ADDRESS, "backupWallet");
    assert.equal(backupTimeout.toString(), ZERO_BN.toString(), 'backupTimeout is not zero');
    assert.equal(backupTimestamp.toString(), ZERO_BN.toString(), 'backupTimestamp is not zero');
    assert.equal(backupActivated, false, 'backupActivated');
  });

  it('only owner can set backup', async () => {
    try {
      await instance.setBackup(user2, 60, { from: user1, nonce: await web3.eth.getTransactionCount(user1) });
      assert(false);
    } catch (err) {
      assertRevert(err);
    }

    let backupWallet = await instance.getBackupWallet();
    let backupTimeout = await instance.getBackupTimeout();
    let backupTimestamp = await instance.getBackupTimestamp();
    let backupActivated = await utils.isBackupActivated(instance);

    assert.equal(backupWallet, ZERO_ADDRESS, "backupWallet");
    assert.equal(backupTimeout.toString(10), ZERO_BN.toString(10), 'backupTimeout');
    assert.equal(backupTimestamp.toString(10), ZERO_BN.toString(10), 'backupTimestamp');
    assert.equal(backupActivated, false, 'backupActivated');

    await instance.setBackup(user1, 120, { from: owner, nonce: await web3.eth.getTransactionCount(owner) });
    blockTimestamp = await utils.getLatestBlockTimestamp(timeUnitInSeconds);

    backupWallet = await instance.getBackupWallet();
    backupTimeout = await instance.getBackupTimeout();
    backupTimestamp = await instance.getBackupTimestamp();
    //backupActivated = await instance.isBackupActivated();
    backupActivated = await utils.isBackupActivated(instance);

    assert.equal(backupWallet, user1, "backupWallet");
    assert.equal(backupTimeout.toString(10), web3.utils.toBN('120').toString(10), `backupTimeout`);
    assert.equal(backupTimestamp.toString(10), web3.utils.toBN('0').toString(10), `backupTimestamp`);
    assert.equal(backupActivated, false, 'backupActivated');
  });

  it('should revert when trying to set empty backup', async () => {
    try {
      await instance.setBackup(ZERO_ADDRESS, 60, { from: owner });
      assert(false);
    } catch (err) {
      assertRevert(err);
    }
  });

  it('should revert when trying to set the owner as a backup', async () => {
    try {
      await instance.setBackup(owner, 120, { from: owner, nonce: await web3.eth.getTransactionCount(owner) });
      assert(false);
    } catch (err) {
      assertRevert(err);
    }
  });

  it ('factory owner and wallet owner are not allowd to call factory.addWalletBackup/.removeWalletBackup directly', async () => {
    const factoryAddress = await instance.creator();
    const factory = await Factory.at(factoryAddress);
    const walletAddress = await factory.getWallet(owner);

    assert.equal(walletAddress, instance.address, 'walletAddress');
   
    try {
      await factory.addWalletBackup(user1, { from: owner, nonce: await web3.eth.getTransactionCount(owner) });
      assert(false);
    } catch (err) {
      assertRevert(err);
    }
    try {
      await factory.addWalletBackup(user1, { from: factoryOwner });
      assert(false);
    } catch (err) {
      assertRevert(err);
    }
    await instance.setBackup(user1, 120, { from: owner, nonce: await web3.eth.getTransactionCount(owner) });
    try {
      await factory.removeWalletBackup(user1, { from: owner });
      assert(false);
    } catch (err) {
      assertRevert(err);
    }
    try {
      await factory.removeWalletBackup(user1, { from: factoryOwner, nonce: await web3.eth.getTransactionCount(factoryOwner) });
      assert(false);
    } catch (err) {
      assertRevert(err);
    }
    await instance.removeBackup({ from: owner, nonce: await web3.eth.getTransactionCount(owner) });

  });

  it('only owner can remove a backup', async () => {
    await instance.setBackup(user1, 120, { from: owner, nonce: await web3.eth.getTransactionCount(owner) });
    try {
      await instance.removeBackup({ from: user1, nonce: await web3.eth.getTransactionCount(user1) });
      assert(false);
    } catch (err) {
      assertRevert(err);
    }
    await instance.removeBackup({ from: owner, nonce: await web3.eth.getTransactionCount(owner) });
    blockTimestamp = await utils.getLatestBlockTimestamp(timeUnitInSeconds);

    const backupWallet = await instance.getBackupWallet();
    const backupTimeout = await instance.getBackupTimeout();
    const backupTimestamp = await instance.getBackupTimestamp();
    const backupActivated = await utils.isBackupActivated(instance);

    assert.equal(backupWallet, ZERO_ADDRESS, "backupWallet");
    assert.equal(backupTimeout.toString(10), ZERO_BN.toString(10), 'backupTimeout');
    assert.equal(backupTimestamp.toString(10), ZERO_BN.toString(10), 'backupTimestamp');
    assert.equal(backupActivated, false, 'backupActivated');
  });

  it('should revert when trying to activate an empty backup', async () => {
    try {
      await instance.activateBackup({ from: owner, nonce: await web3.eth.getTransactionCount(owner) });
      assert(false);
    } catch (err) {
      assertRevert(err);
    }
  });

  it('should emit event "BackupChanged(owner, backupWallet, timeout)" when backup is set', async () => {
    const tx = await instance.setBackup(user2, 240, { from: owner, nonce: await web3.eth.getTransactionCount(owner) });
    // truffleAssert.eventEmitted(tx, 'BackupChanged', (ev) => {
    //   console.log('ev: ' + JSON.stringify(ev))
    //   return ev.owner === owner && ev.wallet === user2 && ev.timeout === 240;
    // });    
    const args = assetEvent_getArgs(tx.logs, 'BackupChanged');
    assert.equal(args.owner, owner, '..(owner, .., ..)');
    assert.equal(args.wallet, user2, '..(.., wallet, ..)');
    assert.equal(args.timeout, 240, '..(.., .., timeout)');
  });


  it('should emit event "BackupRemoved(owner, wallet)" when backup is removed', async () => {
    await instance.setBackup(user2, 240, { from: owner, nonce: await web3.eth.getTransactionCount(owner) });
    const tx = await instance.removeBackup({ from: owner });

    const args = assetEvent_getArgs(tx.logs, 'BackupRemoved');
    assert.equal(args.owner, owner, '..(owner, ..)');
    assert.equal(args.wallet, user2, '..(.., wallet)');
  });


  it('should revert when trying to activate backup before time is out', async () => {
    await instance.setBackup(user1, 120, { from: owner, nonce: await web3.eth.getTransactionCount(owner) });
    try {
      await instance.activateBackup({ from: owner });
      assert(false);
    } catch (err) {
      assertRevert(err);
    }
  });

  it('anyone should be able to activate backup when time is out', async () => {
    await instance.setBackup(user1, 0, { from: owner, nonce: await web3.eth.getTransactionCount(owner) });
    if (instance.accept) await instance.accept({from: user1, nonce: await web3.eth.getTransactionCount(user1) });
    if (instance.enable) await instance.enable({from: user1 });
    blockTimestamp = await utils.getLatestBlockTimestamp(timeUnitInSeconds);

    await instance.activateBackup({ from: user2, nonce: await web3.eth.getTransactionCount(user2) });
  });

  it('should revert when trying to set a backup when backup is activated', async () => {
    try {
      await instance.setBackup(user1, 120, { from: owner, nonce: await web3.eth.getTransactionCount(owner) });
      assert(false);
    } catch (err) {
      assertRevert(err);
    }
  });


  it('should revert when trying to activate a backup when backup is already activated', async () => {
    try {
      await instance.activateBackup({ from: user2, nonce: await web3.eth.getTransactionCount(user2) });
      assert(false);
    } catch (err) {
      assertRevert(err);
    }
  });

  it('only owner can reclaim ownership', async () => {
    try {
      await instance.reclaimOwnership({ from: user1, nonce: await web3.eth.getTransactionCount(user1) });
      assert(false);
    } catch (err) {
      assertRevert(err);
    }
  });

  it('owner should be able to remove a backup when backup is activated', async () => {
    await instance.removeBackup({ from: owner, nonce: await web3.eth.getTransactionCount(owner) });
    blockTimestamp = await utils.getLatestBlockTimestamp(timeUnitInSeconds);

    const backupWallet = await instance.getBackupWallet();
    const backupTimeout = await instance.getBackupTimeout();
    const backupTimestamp = await instance.getBackupTimestamp();
    const backupActivated = await utils.isBackupActivated(instance);

    assert.equal(backupWallet, ZERO_ADDRESS, "backupWallet");
    assert.equal(backupTimeout.toString(10), ZERO_BN.toString(10), 'backupTimeout');
    assert.equal(backupTimestamp.toString(10), ZERO_BN.toString(10), 'backupTimestamp');
    assert.equal(backupActivated, false, 'backupActivated');
  });

  // it('should revert when trying to remove a backup when backup is activated', async () => {
    //   try {
      //     await instance.removeBackup({ from: owner });
      //     assert(false);
  //   } catch (err) {
    //     assertRevert(err);
    //   }
  // });

  it('owner should be able to reclaim ownership when backup is activated', async () => {
    await instance.setBackup(user1, 0, { from: owner, nonce: await web3.eth.getTransactionCount(owner) });
    if (instance.accept) await instance.accept({from: user1, nonce: await web3.eth.getTransactionCount(user1) });
    if (instance.enable) await instance.enable({from: user1 });
    blockTimestamp = await utils.getLatestBlockTimestamp(timeUnitInSeconds);
    await utils.sleep(1000);
    await instance.activateBackup({ from: user2, nonce: await web3.eth.getTransactionCount(user2) });

    let backupWallet = await instance.getBackupWallet();
    let backupTimeout = await instance.getBackupTimeout();
    let backupTimestamp = await instance.getBackupTimestamp();
    let backupActivated = await utils.isBackupActivated(instance);


    assert.equal(backupWallet, user1, "backupWallet");
    assert.equal(backupTimeout.toString(10), ZERO_BN.toString(10), 'backupTimeout');
    assert.equal(backupTimestamp.toString(10), web3.utils.toBN(blockTimestamp.toString()).toString(10), 'backupTimestamp');
    assert.equal(backupActivated, true, 'backupActivated');

    await utils.sleep(2000);

    await instance.reclaimOwnership({ from: owner, nonce: await web3.eth.getTransactionCount(owner) });
    if (instance.enable) await instance.enable({from: user1, nonce: await web3.eth.getTransactionCount(user1) });

    blockTimestamp = await utils.getLatestBlockTimestamp(timeUnitInSeconds);

    backupWallet = await instance.getBackupWallet();
    backupTimeout = await instance.getBackupTimeout();
    backupTimestamp = await instance.getBackupTimestamp();
    backupActivated = await utils.isBackupActivated(instance);


    assert.equal(backupWallet, user1, "backupWallet");
    assert.equal(backupTimeout.toString(10), ZERO_BN.toString(10), 'backupTimeout');
    assert.equal(backupTimestamp.toString(10), web3.utils.toBN(blockTimestamp.toString()).toString(10), 'backupTimestamp');
    assert.equal(backupActivated, false, 'backupActivated');
  });

  /*
  it('should revert when trying to transferOwnership when backup is defined', async () => {
    console.log(instance)
    await instance.setBackup(user1, 0, { from: owner });
    blockTimestamp = await utils.getLatestBlockTimestamp();
    //await instance.activateBackup({ from: user2 });
    await instance.transferOwnership(user2, { from: owner });
  });
  */
});
};
