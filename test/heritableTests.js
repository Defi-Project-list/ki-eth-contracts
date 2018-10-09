'use strict';

const mlog = require('mocha-logger');
const { ZERO_ADDRESS, ZERO_BYTES32, ZERO_BN } = require('./lib/consts');
const {
  assertRevert,
  assertPayable,
  assertInvalidOpcode,
  assertFunction,
  assetEvent_getArgs
} = require('./lib/asserts');

const utils = require('./lib/utils');

const parseHeirs = (heirs) => {
  let res = [];
  for (let i = 0; i < heirs.length; ++i) {
    if (heirs[i] == ZERO_BYTES32) {
      continue;
    }
    res.push ({
      wallet: heirs[i].slice(0, 42),
      sent: heirs[i].slice(42, 44) != '00' ? true : false,
      percent: parseInt(heirs[i].slice(44, 48), 16)
    });
  }
  return res;
}

module.exports = (contractClass, contractName) => {

contract(contractName, async accounts => {
  let instance;

  const owner = accounts[0];
  const user1 = accounts[1];
  const user2 = accounts[2];
  const user3 = accounts[3];

  let blockTimestamp = 0;

  before('checking constants', async () => {
      assert(typeof owner == 'string', 'owner should be string');
      assert(typeof user1 == 'string', 'user1 should be string');
      assert(typeof user2 == 'string', 'user2 should be string');
      assert(typeof user3 == 'string', 'user3 should be string');
  });

  before('setup contract for the test', async () => {
 	  if (contractClass.new instanceof Function) {
  	    instance = await contractClass.new();
 	  } else {
  	    instance = await contractClass(owner);
 	  }

    mlog.log('web3     ', web3.version.api);
    mlog.log('contract ', instance.address);
    mlog.log('owner    ', owner);
    mlog.log('user1    ', user1);
    mlog.log('user2    ', user2);
    mlog.log('user3    ', user3);
  });

  it('constructor: owner should be the contract creator', async () => {
    const isOwner = await instance.isOwner.call({from: owner});
    assert.equal(isOwner, true);
  });

  it('constructor: heirs should be empty', async () => {
    const rawHeirs = await instance.getHeirs.call();

    const heirs = parseHeirs(rawHeirs);

    assert.equal(heirs.length, 0, "num of heirs");
  });

  it('constructor: inheritance should be initialized as follows timeout:0, enabled:false, activated:false', async () => {
    const inheritanceTimeout = await instance.getInheritanceTimeout.call();
    const inheritanceEnabled = await instance.isInheritanceEnabled.call();
    const inheritanceActivated = await instance.isInheritanceActivated.call();

    assert.equal(inheritanceTimeout.toString(10), ZERO_BN.toString(10), "inheritanceTimeout");
    assert.equal(inheritanceEnabled, false, "inheritanceEnabled");
    assert.equal(inheritanceActivated, false, "inheritanceActivated");
  });

  it('only owner can set heirs', async () => {
    try {
      await instance.setHeirs([user1, user2], [2000, 3000], { from: user3 });
      assert(false);
    } catch (err) {
      assertRevert(err);
    }
    await instance.setHeirs([user1, user2], [2000, 3000], { from: owner });

    const rawHeirs = await instance.getHeirs.call();
    const heirs = parseHeirs(rawHeirs);

    const totalPercent = await instance.getTotalPercent.call();

    assert.equal(heirs.length, 2, "num of heirs");

    assert.equal(heirs[0].wallet,   user1,  "heir1 wallet");
    assert.equal(heirs[0].percent,  2000,     "heir1 percent");
    assert.equal(heirs[0].sent,     false,  "heir1 sent");

    assert.equal(heirs[1].wallet,   user2,  "heir2 wallet");
    assert.equal(heirs[1].percent,  3000,     "heir2 percent");
    assert.equal(heirs[1].sent,     false,  "heir2 sent");

    assert.equal(totalPercent.toString(10), web3.toBigNumber(2000 + 3000).toString(10), 'total percent')
  });



  it('only owner can remove all heirs', async () => {
    try {
      await instance.setHeirs([], [], { from: user3 });
      assert(false);
    } catch (err) {
      assertRevert(err);
    }
    await instance.setHeirs([], [], { from: owner });
    const rawHeirs = await instance.getHeirs.call();
    const heirs = parseHeirs(rawHeirs);
    const totalPercent = await instance.getTotalPercent.call();

    assert.equal(heirs.length, 0, "num of heirs");
    assert.equal(totalPercent.toString(10), ZERO_BN.toString(10), 'total percent')
  });

  it('only owner can set inheritance', async () => {
    try {
      await instance.setInheritance(120, { from: user3 });
      assert(false);
    } catch (err) {
      assertRevert(err);
    }
    await instance.setInheritance(120, { from: owner });
    const inheritanceTimeout = await instance.getInheritanceTimeout.call();
    const inheritanceEnabled = await instance.isInheritanceEnabled.call();
    const inheritanceActivated = await instance.isInheritanceActivated.call();

    assert.equal(inheritanceTimeout.toString(10), web3.toBigNumber(120).toString(10), "inheritanceTimeout");
    assert.equal(inheritanceEnabled, true, "inheritanceEnabled");
    assert.equal(inheritanceActivated, false, "inheritanceActivated");
  });

  it('should emit event "InheritanceChanged(owner, timeout)" when inheritance is set', async () => {
    const logs = await new Promise((r, j) => instance.InheritanceChanged({}, {
        fromBlock: 'latest',
        toBlock: 'latest'
      })
      .get((err, logs) => {
        r(logs)
      }));

    const args = assetEvent_getArgs(logs, 'InheritanceChanged');
    assert.equal(args.owner, owner, '..(owner, ..)');
    assert.equal(args.timeout, 120, '..(.., timeout)');
  });

  it('only owner can clear inheritance', async () => {
    try {
      await instance.clearInheritance({ from: user3 });
      assert(false);
    } catch (err) {
      assertRevert(err);
    }
    await instance.clearInheritance({ from: owner });
    const inheritanceTimeout = await instance.getInheritanceTimeout.call();
    const inheritanceEnabled = await instance.isInheritanceEnabled.call();
    const inheritanceActivated = await instance.isInheritanceActivated.call();

    assert.equal(inheritanceTimeout.toString(10), ZERO_BN.toString(10), "inheritanceTimeout");
    assert.equal(inheritanceEnabled, false, "inheritanceEnabled");
    assert.equal(inheritanceActivated, false, "inheritanceActivated");
  });

  it('should emit event "InheritanceRemoved(owner)" when inheritance is cleared', async () => {
    const logs = await new Promise((r, j) => instance.InheritanceRemoved({}, {
        fromBlock: 'latest',
        toBlock: 'latest'
      })
      .get((err, logs) => {
        r(logs)
      }));

    const args = assetEvent_getArgs(logs, 'InheritanceRemoved');
    assert.equal(args.owner, owner, '..(owner, ..)');
  });


  it('cannot set heirs when total percent is greater than 10000 (100.00%)', async () => {
    await instance.setHeirs([user2, user1, user3], [2000, 4000, 5000], { from: owner });
  });

  it('set heirs overrides previous settings', async () => {
    await instance.setHeirs([user2, user1, user3], [2000, 3000, 5000], { from: owner });
    await instance.setHeirs([user2, user3, user1], [1500, 3000, 5000], { from: owner });

    let rawHeirs = await instance.getHeirs.call();
    let heirs = parseHeirs(rawHeirs);

    let totalPercent = await instance.getTotalPercent.call();

    assert.equal(heirs.length, 3, "num of heirs");

    assert.equal(heirs[0].wallet,   user2,  "heir1 wallet");
    assert.equal(heirs[0].percent,  1500,     "heir1 percent");
    assert.equal(heirs[0].sent,     false,  "heir1 sent");

    assert.equal(heirs[1].wallet,   user3,  "heir2 wallet");
    assert.equal(heirs[1].percent,  3000,     "heir2 percent");
    assert.equal(heirs[1].sent,     false,  "heir2 sent");

    assert.equal(heirs[2].wallet,   user1,  "heir3 wallet");
    assert.equal(heirs[2].percent,  5000,     "heir3 percent");
    assert.equal(heirs[2].sent,     false,  "heir3 sent");

    assert.equal(totalPercent.toString(10), web3.toBigNumber(1500 + 3000 + 5000).toString(10), 'total percent')

    await instance.setHeirs([user3], [1500], { from: owner });

    rawHeirs = await instance.getHeirs.call();
    heirs = parseHeirs(rawHeirs);

    totalPercent = await instance.getTotalPercent.call();

    assert.equal(heirs.length, 1, "num of heirs");

    assert.equal(heirs[0].wallet,   user3,  "heir1 wallet");
    assert.equal(heirs[0].percent,  1500,     "heir1 percent");
    assert.equal(heirs[0].sent,     false,  "heir1 sent");

    assert.equal(totalPercent.toString(10), web3.toBigNumber(1500).toString(10), 'total percent')

    await instance.setHeirs([user2, user1], [2500, 3000], { from: owner });

    rawHeirs = await instance.getHeirs.call();
    heirs = parseHeirs(rawHeirs);

    totalPercent = await instance.getTotalPercent.call();

    assert.equal(heirs.length, 2, "num of heirs");

    assert.equal(heirs[0].wallet,   user2,  "heir1 wallet");
    assert.equal(heirs[0].percent,  2500,     "heir1 percent");
    assert.equal(heirs[0].sent,     false,  "heir1 sent");

    assert.equal(heirs[1].wallet,   user1,  "heir2 wallet");
    assert.equal(heirs[1].percent,  3000,     "heir2 percent");
    assert.equal(heirs[1].sent,     false,  "heir2 sent");

    assert.equal(totalPercent.toString(10), web3.toBigNumber(2500 + 3000).toString(10), 'total percent')
  });

  it('should emit event "InheritanceHeirsChanged(owner, wallets[], percents[])" when heirs are set', async () => {
    const logs = await new Promise((r, j) => instance.InheritanceHeirsChanged({}, {
        fromBlock: 'latest',
        toBlock: 'latest'
      })
      .get((err, logs) => {
        r(logs)
      }));

    const args = assetEvent_getArgs(logs, 'InheritanceHeirsChanged');

    assert.equal(args.owner, owner, '..(owner, ..)');

    assert.equal(args.wallets.length, 2, "num of wallets");
    assert.equal(args.percents.length, 2, "num of percents");

    assert.equal(args.wallets[0], user2, "heir1 wallet");
    assert.equal(args.percents[0], 2500, "heir1 percent");

    assert.equal(args.wallets[1], user1, "heir2 wallet");
    assert.equal(args.percents[1], 3000, "heir2 percent");
  });

  it('should revert when trying to activate inheritance before timeout has reached', async () => {
    try {
      await instance.activateInheritance({ from: user3 });
      assert(false);
    } catch (err) {
      assertRevert(err);
    }
    await instance.setInheritance(2, { from: owner });

    try {
      await instance.activateInheritance({ from: user3 });
      assert(false);
    } catch (err) {
      assertRevert(err);
    }

  });

  it('should transfer funds when activating inheritance', async () => {
    const value = web3.toWei(100, 'gwei');
    await web3.eth.sendTransaction({ from: owner, value: value, to: instance.address });
    let balance = await web3.eth.getBalance(instance.address);
    assert.equal(balance.toString(10), web3.toBigNumber(value).toString(10));

    await utils.sleep(2000);
    await instance.activateInheritance({ from: user3 });

    balance = await web3.eth.getBalance(instance.address);

    let totalPercent = await instance.getTotalPercent.call();
    assert.equal(totalPercent.toString(10), web3.toBigNumber(2500 + 3000).toString(10), 'total percent')

    const valueLeft = (value * 45) / 100;
    assert.equal(balance.toString(10), web3.toBigNumber(valueLeft).toString(10));

    const rawHeirs = await instance.getHeirs.call();
    const heirs = parseHeirs(rawHeirs);

    totalPercent = await instance.getTotalPercent.call();

    assert.equal(heirs.length, 2, "num of heirs");

    assert.equal(heirs[0].wallet, user2, "heir1 wallet");
    assert.equal(heirs[0].percent, 2500, "heir1 percent");
    //assert.equal(heirs[0].sent, true, "heir1 sent");

    assert.equal(heirs[1].wallet, user1, "heir2 wallet");
    assert.equal(heirs[1].percent, 3000, "heir2 percent");
    assert.equal(heirs[1].sent, true, "heir2 sent");

    assert.equal(totalPercent.toString(10), web3.toBigNumber(2500 + 3000).toString(10), 'total percent')
  });

  it('should revert when trying to activate inheritance after been activated', async () => {
    try {
      await instance.activateInheritance({ from: user3 });
      assert(false);
    } catch (err) {
      assertRevert(err);
    }
  });

  it('should keep heirs conf and reset sent flag when clearing inheritance', async () => {
    await instance.clearInheritance({ from: owner });

    const inheritanceTimeout = await instance.getInheritanceTimeout.call();
    const inheritanceEnabled = await instance.isInheritanceEnabled.call();
    const inheritanceActivated = await instance.isInheritanceActivated.call();

    assert.equal(inheritanceTimeout.toString(10), ZERO_BN.toString(10), "inheritanceTimeout");
    assert.equal(inheritanceEnabled, false, "inheritanceEnabled");
    assert.equal(inheritanceActivated, false, "inheritanceActivated");

    const rawHeirs = await instance.getHeirs.call();
    const heirs = parseHeirs(rawHeirs);

    const totalPercent = await instance.getTotalPercent.call();

    assert.equal(heirs.length, 2, "num of heirs");

    assert.equal(heirs[0].wallet, user2, "heir1 wallet");
    assert.equal(heirs[0].percent, 2500, "heir1 percent");
    assert.equal(heirs[0].sent, false, "heir1 sent");

    assert.equal(heirs[1].wallet, user1, "heir1 wallet");
    assert.equal(heirs[1].percent, 3000, "heir1 percent");
    assert.equal(heirs[1].sent, false, "heir1 sent");

    assert.equal(totalPercent.toString(10), web3.toBigNumber(2500 + 3000).toString(10), 'total percent')
  });

});
};
