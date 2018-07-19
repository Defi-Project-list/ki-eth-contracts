'use strict';

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

module.exports = (contractClass, contractName) => {

contract(contractName, async accounts => {
  let instance;

  const owner = accounts[0];
  const user1 = accounts[1];
  const user2 = accounts[2];

  let blockTimestamp = 0;

  before('checking constants', async () => {
      assert(typeof owner == 'string', 'owner should be string');
      assert(typeof user1 == 'string', 'user1 should be string');
      assert(typeof user2 == 'string', 'user2 should be string');
  });

  before('setup contract for the test', async () => {
	  if (contractClass.new instanceof Function) {
      instance = await contractClass.new();
	  }
	  else {
      instance = await contractClass(owner);
	  }

    mlog.log('web3     ', web3.version.api);
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
    const backupActivated = await instance.isBackupActivated();

    assert.equal(backupWallet, ZERO_ADDRESS, "backupWallet");
    assert.ok(backupTimeout.equals(ZERO_BN), 'backupTimeout is not zero');
    assert.ok(backupTimestamp.equals(ZERO_BN), 'backupTimestamp is not zero');
    assert.equal(backupActivated, false, 'backupActivated');
  });

  it('only owner can set backup', async () => {
    try {
      await instance.setBackup(user2, 60, { from: user1 });
      assert(false);
    } catch (err) {
      assertRevert(err);
    }

    let backupWallet = await instance.getBackupWallet();
    let backupTimeout = await instance.getBackupTimeout();
    let backupTimestamp = await instance.getBackupTimestamp();
    let backupActivated = await instance.isBackupActivated();

    assert.equal(backupWallet, ZERO_ADDRESS, "backupWallet");
    assert.equal(backupTimeout.toString(10), ZERO_BN.toString(10), 'backupTimeout');
    assert.equal(backupTimestamp.toString(10), ZERO_BN.toString(10), 'backupTimestamp');
    assert.equal(backupActivated, false, 'backupActivated');

    await instance.setBackup(user1, 120, { from: owner });
    blockTimestamp = await utils.getLatestBlockTimestamp();

    backupWallet = await instance.getBackupWallet();
    backupTimeout = await instance.getBackupTimeout();
    backupTimestamp = await instance.getBackupTimestamp();
    backupActivated = await instance.isBackupActivated();

    assert.equal(backupWallet, user1, "backupWallet");
    assert.equal(backupTimeout.toString(10), web3.toBigNumber(120).toString(10), `backupTimeout`);
    assert.equal(backupTimestamp.toString(10), web3.toBigNumber(blockTimestamp).toString(10), `backupTimestamp`);
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
      await instance.setBackup(owner, 120, { from: owner });
      assert(false);
    } catch (err) {
      assertRevert(err);
    }
  });

  it('only owner can remove a backup', async () => {
    await instance.setBackup(user1, 120, { from: owner });
    try {
      await instance.removeBackup({ from: user1 });
      assert(false);
    } catch (err) {
      assertRevert(err);
    }
    await instance.removeBackup({ from: owner });
    blockTimestamp = await utils.getLatestBlockTimestamp();

    const backupWallet = await instance.getBackupWallet();
    const backupTimeout = await instance.getBackupTimeout();
    const backupTimestamp = await instance.getBackupTimestamp();
    const backupActivated = await instance.isBackupActivated();

    assert.equal(backupWallet, ZERO_ADDRESS, "backupWallet");
    assert.equal(backupTimeout.toString(10), ZERO_BN.toString(10), 'backupTimeout');
    assert.equal(backupTimestamp.toString(10), blockTimestamp, 'backupTimestamp');
    assert.equal(backupActivated, false, 'backupActivated');
  });

  it('should revert when trying to activate an empty backup', async () => {
    try {
      await instance.activateBackup({ from: owner });
      assert(false);
    } catch (err) {
      assertRevert(err);
    }
  });

  it('should emit event "BackupChanged(owner, backupWallet, timeout)" when backup is set', async () => {
    await instance.setBackup(user2, 240, { from: owner });

    const logs = await new Promise((r, j) => instance.BackupChanged({}, {
        fromBlock: 'latest',
        toBlock: 'latest'
      })
      .get((err, logs) => {
        r(logs)
      }));

    const args = assetEvent_getArgs(logs, 'BackupChanged');
    assert.equal(args.owner, owner, '..(owner, .., ..)');
    assert.equal(args.wallet, user2, '..(.., wallet, ..)');
    assert.equal(args.timeout, 240, '..(.., .., timeout)');
  });


  it('should emit event "BackupRemoved(owner, wallet)" when backup is removed', async () => {
    await instance.setBackup(user2, 240, { from: owner });
    await instance.removeBackup({ from: owner });
    const logs = await new Promise((r, j) => instance.BackupRemoved({}, {
        fromBlock: 'latest',
        toBlock: 'latest'
      })
      .get((err, logs) => {
        r(logs)
      }));

    const args = assetEvent_getArgs(logs, 'BackupRemoved');
    assert.equal(args.owner, owner, '..(owner, ..)');
    assert.equal(args.wallet, user2, '..(.., wallet)');
  });


  it('should revert when trying to activate backup before time is out', async () => {
    await instance.setBackup(user1, 120, { from: owner });
    try {
      await instance.activateBackup({ from: owner });
      assert(false);
    } catch (err) {
      assertRevert(err);
    }
  });

  it('anyone should be able to activate backup when time is out', async () => {
    await instance.setBackup(user1, 0, { from: owner });
    blockTimestamp = await utils.getLatestBlockTimestamp();

    await instance.activateBackup({ from: user2 });
  });

  it('should revert when trying to set a backup when backup is activated', async () => {
    try {
      await instance.setBackup(user1, 120, { from: owner });
      assert(false);
    } catch (err) {
      assertRevert(err);
    }
  });


  it('should revert when trying to activate a backup when backup is already activated', async () => {
    try {
      await instance.activateBackup({ from: user2 });
      assert(false);
    } catch (err) {
      assertRevert(err);
    }
  });

  it('only owner can reclaim ownership', async () => {
    try {
      await instance.reclaimOwnership({ from: user1 });
      assert(false);
    } catch (err) {
      assertRevert(err);
    }
  });

  it('owner should be able to remove a backup when backup is activated', async () => {
    await instance.removeBackup({ from: owner });
    blockTimestamp = await utils.getLatestBlockTimestamp();

    const backupWallet = await instance.getBackupWallet();
    const backupTimeout = await instance.getBackupTimeout();
    const backupTimestamp = await instance.getBackupTimestamp();
    const backupActivated = await instance.isBackupActivated();

    assert.equal(backupWallet, ZERO_ADDRESS, "backupWallet");
    assert.equal(backupTimeout.toString(10), ZERO_BN.toString(10), 'backupTimeout');
    assert.equal(backupTimestamp.toString(10), blockTimestamp, 'backupTimestamp');
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

    await instance.setBackup(user1, 0, { from: owner });
    blockTimestamp = await utils.getLatestBlockTimestamp();
    await instance.activateBackup({ from: user2 });

    let backupWallet = await instance.getBackupWallet();
    let backupTimeout = await instance.getBackupTimeout();
    let backupTimestamp = await instance.getBackupTimestamp();
    let backupActivated = await instance.isBackupActivated();

    assert.equal(backupWallet, user1, "backupWallet");
    assert.equal(backupTimeout.toString(10), ZERO_BN.toString(10), 'backupTimeout');
    assert.equal(backupTimestamp.toString(10), web3.toBigNumber(blockTimestamp).toString(10), 'backupTimestamp');
    assert.equal(backupActivated, true, 'backupActivated');

    await utils.sleep(2000);

    await instance.reclaimOwnership({ from: owner });
    blockTimestamp = await utils.getLatestBlockTimestamp();

    backupWallet = await instance.getBackupWallet();
    backupTimeout = await instance.getBackupTimeout();
    backupTimestamp = await instance.getBackupTimestamp();
    backupActivated = await instance.isBackupActivated();

    assert.equal(backupWallet, user1, "backupWallet");
    assert.equal(backupTimeout.toString(10), ZERO_BN.toString(10), 'backupTimeout');
    assert.equal(backupTimestamp.toString(10), web3.toBigNumber(blockTimestamp).toString(10), 'backupTimestamp');
    assert.equal(backupActivated, false, 'backupActivated');
  });

  /*
  it('should revert when trying to transferOwnership when backup is defined', async () => {
    await instance.setBackup(user1, 0, { from: owner });
    blockTimestamp = await utils.getLatestBlockTimestamp();
    //await instance.activateBackup({ from: user2 });
    await instance.transferOwnership(user2, { from: owner });
``
  });
  */
});
};
