const Backupable = artifacts.require("Backupable");
const mlog = require('mocha-logger');
const { ZERO_ADDRESS, ZERO_BN } = require('./lib/consts');
const {
  assertRevert,
  assertInvalidOpcode,
  assertPayable,
  assertFunction,
  assetEvent_getArgs
} = require('./lib/asserts');

console.log("Using web3 '" + web3.version.api + "'");

contract('Backupable', async accounts => {
  let instance;

  const owner = accounts[0];
  const user1 = accounts[1];
  const user2 = accounts[2];

  before('checking constants', async () => {
      assert(typeof owner == 'string', 'owner should be string');
      assert(typeof user1 == 'string', 'user1 should be string');
      assert(typeof user2 == 'string', 'user2 should be string');
  });

  before('setup contract for the test', async () => {
    instance = await Backupable.new();

    mlog.log('contract ', instance.address);
    mlog.log('owner    ', owner);
    mlog.log('user1    ', user1);
    mlog.log('user2    ', user2);
  });

  it('constructor: owner should be the contract creator', async () => {
    const contractOwner = await instance.owner.call();
    assert.equal(contractOwner, owner);
  });

  it('constructor: backupInfo should be empty', async () => {
    const backupWallet = await instance.getBackupWallet();
    const backupTimeout = await instance.getBackupTimeout();
    const backupTimestamp = await instance.getBackupTimestamp();
    const isBackupActivated = await instance.isBackupActivated();

    assert.equal(backupWallet, ZERO_ADDRESS, "backupWallet");
    assert.ok(backupTimeout.equals(ZERO_BN), 'backupTimeout is not zero');
    assert.ok(backupTimestamp.equals(ZERO_BN), 'backupTimestamp is not zero');
    assert.equal(isBackupActivated, false, 'isBackupActivated');
  });


  // it('only owner can transfer ownership', async () => {
  //   try {
  //     await instance.transferOwnership(user2, { from: user1 });
  //     assert(false);
  //   } catch (err) {
  //     assertRevert(err);
  //   }
  //   await instance.transferOwnership(user1, { from: owner });
  //   const pendingOwner = await instance.pendingOwner.call();
  //   assert.equal(pendingOwner, user1);
  // });

  // it('only owner can reclaim ownership', async () => {
  //   try {
  //     await instance.reclaimOwnership({ from: user1 });
  //     assert(false);
  //   } catch (err) {
  //     assertRevert(err);
  //   }

  //   await instance.reclaimOwnership({ from: owner });
  //   const contactOwner = await instance.owner.call();
  //   const pendingOwner = await instance.pendingOwner.call();
  //   assert.equal(contactOwner, owner);
  //   assert.equal(pendingOwner, ZERO_ADDRESS);
  // });

  // it ('only pending owner can claim ownership', async () => {
  //   await instance.transferOwnership(user2, { from:owner });
  //   try {
  //     await instance.claimOwnership({ from: owner });
  //     assert(false);
  //   } catch (err) {
  //     assertRevert(err);
  //   }
  //   try {
  //     await instance.claimOwnership({ from: user1 });
  //     assert(false);
  //   } catch (err) {
  //     assertRevert(err);
  //   }
  //   await instance.claimOwnership({ from: user2 });
  //   const contactOwner = await instance.owner.call();
  //   const pendingOwner = await instance.pendingOwner.call();
  //   assert.equal(contactOwner, user2);
  //   assert.equal(pendingOwner, ZERO_ADDRESS);
  // });

  // it ('should reject when trying to call internal _transferOwnership', async ()=> {
  //   try {
  //     await instance._transferOwnership(user1, { from: user2 });
  //     assert(false);
  //   } catch (err) {
  //     assertFunction(err);
  //   }
  // });

  // it('should emit event "OwnershipTransferred(to)" when owner is changed', async () => {
  //   await instance.transferOwnership(user1, { from: user2 });
  //   await instance.claimOwnership({ from: user1 });

  //   const logs = await new Promise((r, j) => instance.OwnershipTransferred({}, {
  //        fromBlock: 'latest',
  //        toBlock: 'latest'
  //      })
  //      .get((err, logs) => {
  //        r(logs)
  //      }));

  //    const args = assetEvent_getArgs(logs, 'OwnershipTransferred');
  //    assert.equal(args.previousOwner, user2, '..(previousOwner, ..)');
  //    assert.equal(args.newOwner, user1, '..(.., newOwner)');
  //  });

});
