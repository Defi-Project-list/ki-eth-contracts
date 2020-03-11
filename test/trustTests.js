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

module.exports = (contractClass, contractName) => {

contract(contractName, async accounts => {
  let instance;

  const owner = accounts[0];
  const user1 = accounts[1];
  const user2 = accounts[2];
  const user3 = accounts[3];

  const startDelay     = 5;
  const wallet         = user1;
  let   start          = 0; //Math.floor((new Date()).getTime() / 1000) + startDelay;
  const period         = 4;
  const times          = 5;
  const amount         = 1000;
  const cancelable     = true;
  const value          = web3.utils.toBN('10000000');
  let   blockTimestamp = 0;

  before('checking constants', async () => {
      assert(typeof owner == 'string', 'owner should be string');
      assert(typeof user1 == 'string', 'user1 should be string');
      assert(typeof user2 == 'string', 'user2 should be string');
      assert(typeof user3 == 'string', 'user3 should be string');
  });

  before('setup contract for the test', async () => {
    // await utils.mine(owner);
    await utils.advanceBlock()
    blockTimestamp = await utils.getLatestBlockTimestamp();
    start = blockTimestamp + startDelay;
    await web3.eth.getTransactionCount(owner)

 	  if (contractClass.new instanceof Function) {
      instance = await contractClass.new(wallet, start, period, times, amount, cancelable, { from: owner, value });
 	  } else {
 	    instance = await contractClass(owner, wallet, start, period, times, amount, cancelable);
 	  }

    mlog.log('web3     ', web3.version);
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


  it('constructor: balance should equal msg.value ', async () => {
    const trustBalance = await web3.eth.getBalance(instance.address);
  });


  it('constructor: trust-struct should hold arguments values', async () => {
    const fund = await instance.fund.call({from: owner});
    assert.equal(fund[0], wallet, "wallet");
    assert.equal(fund[1].toString(10), start.toString(10), "start");
    assert.equal(fund[2], period, "period");
    assert.equal(fund[3], times, "times");
    assert.equal(fund[4], cancelable, "cancelable");
    const perPayAmount = await instance.getPaymentAmount.call({from: owner});
    assert.equal(perPayAmount, amount, "amount");
  });

  it('should return contract balance when calling getBalance', async () => {
    const trustBalance = await web3.eth.getBalance(instance.address);
    const contractBalance = await instance.getBalance.call();
    assert.equal(trustBalance.toString(10), contractBalance.toString(10), "Balance");
  });

  it('should return 0 as payment value when start timestamp is greater than now', async () => {
    const paymentValue = await instance.getPaymentValue.call();
    assert.equal(paymentValue.toString(10), ZERO_BN.toString(10), "paymentValue");
  });

  it('should return start as next payment timestamp when now is greater than start timestamp', async () => {
    const nextPaymentTimestamp = await instance.getNextPaymentTimestamp.call();
    assert.equal(nextPaymentTimestamp.toString(10), start.toString(10), "getNextPaymentTimestamp");
  });

  it('should revert when trying to activate when now > start', async () => {
    await web3.eth.getTransactionCount(owner)
    try {
      await instance.activateTrust({ from: owner });
      assert(false);
    } catch (err) {
      assertRevert(err);
    }
  });

  it('should return amount as payment value when in first period when start>now before activation', async () => {
    await web3.eth.getTransactionCount(owner)
    // await utils.sleep(startDelay*1000);
    // await utils.mine(owner);
    await utils.advanceTimeAndBlock(startDelay)
    const paymentValue = await instance.getPaymentValue.call();
    assert.equal(paymentValue.toString(10), amount.toString(10), "getPaymentValue==amount");
  });

  it('should return start as next payment timestamp when { now <= start < (now + period) }, before first activation', async () => {
    const nextPaymentTimestamp = await instance.getNextPaymentTimestamp.call();
    assert.equal(nextPaymentTimestamp.toString(10), start.toString(10), "getNextPaymentTimestamp");
  });

  it('should return 0 as payed value when { now <= start < (now + period) }, before first activation', async () => {
    const totalPayed = await instance.getTotalPayed.call();
    assert.equal(totalPayed.toString(10), ZERO_BN.toString(10), "getTotalPayed == 0");
  });

  it('should transfer amount to wallet by activating trust at timestamp: { now <= timestamp < now + period }', async () => {
    const trustBalance = await web3.eth.getBalance(instance.address);
    const walletBalance = await web3.eth.getBalance(wallet);
    await instance.activateTrust({from: owner, nonce: await web3.eth.getTransactionCount(owner)});
    const trustDiff = web3.utils.toBN(trustBalance).sub(web3.utils.toBN(await web3.eth.getBalance(instance.address)));
    const walletDiff = web3.utils.toBN(await web3.eth.getBalance(wallet)).sub(web3.utils.toBN(walletBalance));
    assert(trustDiff.toString(10), amount.toString(10), 'trust balance change');
    assert(walletDiff.toString(10), amount.toString(10), 'wallet balance change');
  });

  it('should return 0 as payment value when in first period when start>now after activation', async () => {
    const paymentValue = await instance.getPaymentValue.call();
    assert.equal(paymentValue.toString(10), ZERO_BN.toString(10), "getPaymentValue==0");
  });

  it('should return start+period as next payment timestamp when { now <= start < (now + period) }, after first activation', async () => {
    const nextPaymentTimestamp = await instance.getNextPaymentTimestamp.call();
    assert.equal(nextPaymentTimestamp.toString(10), (start + period).toString(10), "getNextPaymentTimestamp");
  });

  it('should return amount as payed value when { now <= start < (now + period) }, after first activation', async () => {
    const totalPayed = await instance.getTotalPayed.call();
    assert.equal(totalPayed.toString(10), amount.toString(10), "getTotalPayed == amount");
  });

  it('should return (amount*2) as payment value when two periods passed without activation', async () => {
    // await utils.sleep(period * 2 * 1000);
    // await utils.mine(owner);
    await utils.advanceTimeAndBlock(+period * 2)
    const paymentValue = await instance.getPaymentValue.call();
    assert.equal(paymentValue.toString(10), (amount * 2).toString(10), "getPaymentValue==(amount*2)");
  });

  it('should return lowest possible timestamp as next payment timestamp even when two periods passed', async () => {
    const nextPaymentTimestamp = await instance.getNextPaymentTimestamp.call();
    assert.equal(nextPaymentTimestamp.toString(10), (+ start + period).toString(10), "getNextPaymentTimestamp");
  });

  it('should return latest activation time payed value when additional periods passed without activation', async () => {
    const totalPayed = await instance.getTotalPayed.call();
    assert.equal(totalPayed.toString(10), amount.toString(10), "getTotalPayed == amount");
  });

  it('should transfer (amount*2) to wallet by activating trust after two periods passed from last activation', async () => {
    const trustBalance = await web3.eth.getBalance(instance.address);
    const walletBalance = await web3.eth.getBalance(wallet);
    await instance.activateTrust({from: owner});
    const trustDiff = web3.utils.toBN(trustBalance).sub(web3.utils.toBN(await web3.eth.getBalance(instance.address)));
    const walletDiff = web3.utils.toBN(await web3.eth.getBalance(wallet)).sub(web3.utils.toBN(walletBalance));
    assert(trustDiff.toString(10), (amount * 2).toString(10), 'trust balance change');
    assert(walletDiff.toString(10), (amount * 2).toString(10), 'wallet ba(lance *2)change');
  });

  it('should return 0 as payment value after activation', async () => {
    const paymentValue = await instance.getPaymentValue.call();
    assert.equal(paymentValue.toString(10), ZERO_BN.toString(10), "getPaymentValue==0");
  });

  it('should return (start+(period*3)) as next payment timestamp when 3 periods passed and activated', async () => {
    const nextPaymentTimestamp = await instance.getNextPaymentTimestamp.call();
    assert.equal(nextPaymentTimestamp.toString(10), (+start + +period * 3).toString(10), "getNextPaymentTimestamp");
  });

  it('should return (amount*3) as payed value when 3 periods passed and activated', async () => {
    const totalPayed = await instance.getTotalPayed.call();
    assert.equal(totalPayed.toString(10), (amount*3).toString(10), "getTotalPayed == amount");
  });

  it('should return all left trust contract balance as payment value when last period passed', async () => {
    const trustBalance = await web3.eth.getBalance(instance.address);
    // await utils.mine(owner);
    await utils.advanceBlock()
    blockTimestamp = await utils.getLatestBlockTimestamp();
    // await utils.sleep((start + period*times - blockTimestamp)*1000);
    await utils.advanceTimeAndBlock((+ start + period*times - blockTimestamp))
    const paymentValue = await instance.getPaymentValue.call();
    assert.equal(paymentValue.toString(10), trustBalance.toString(10), "getPaymentValue==0");
  });

  it('should transfer all remain trust contract funds to wallet upon activation in case last period passed', async () => {
    const walletBalance = await web3.eth.getBalance(wallet);
    const trustBalance = await web3.eth.getBalance(instance.address);
    await instance.activateTrust();
    const trustDiff = web3.utils.toBN(trustBalance).sub(web3.utils.toBN(await web3.eth.getBalance(instance.address)));
    const walletDiff = web3.utils.toBN(await web3.eth.getBalance(wallet)).sub(web3.utils.toBN(walletBalance));
    assert.equal(trustDiff.toString(10), trustBalance.toString(10) , 'trustDiff == trustBalance');
    assert.equal(walletDiff.toString(10), trustBalance.toString(10) , 'walletDiff == trustBalance');
  });

});
}
