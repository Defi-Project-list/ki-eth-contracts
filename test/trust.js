const Trust = artifacts.require("Trust");
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

console.log("Using web3 '" + web3.version.api + "'");

contract('Trust', async accounts => {
  let instance;

  const owner = accounts[0];
  const user1 = accounts[1];
  const user2 = accounts[2];
  const user3 = accounts[3];

  const startDelay     = 3;
  const wallet         = user1;
  let   start          = 0; //Math.floor((new Date()).getTime() / 1000) + startDelay;
  const period         = 2;
  const times          = 5;
  const amount         = 1000;
  const cancelable     = true;
  const value          = web3.toBigNumber(10000000);
  let   blockTimestamp = 0;

  before('checking constants', async () => {
      assert(typeof owner == 'string', 'owner should be string');
      assert(typeof user1 == 'string', 'user1 should be string');
      assert(typeof user2 == 'string', 'user2 should be string');
      assert(typeof user3 == 'string', 'user3 should be string');
  });

  before('setup contract for the test', async () => {
    await utils.mine(owner);
    blockTimestamp = await utils.getLatestBlockTimestamp();
    start = blockTimestamp + startDelay;

    instance = await Trust.new(
      wallet,
      start,
      period,
      times,
      amount,
      cancelable,
      { from:owner, value });

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
    assert.equal(fund[0], wallet);
    assert.equal(fund[1].toString(10), start.toString(10));
    assert.equal(fund[2], period);
    assert.equal(fund[3], times);
    assert.equal(fund[4], cancelable);
    const perPayAmount = await instance.getPaymentAmount.call({from: owner});
    assert.equal(perPayAmount, amount);
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
    try {
      await instance.activateTrust({ from: owner });
      assert(false);
    } catch (err) {
      assertRevert(err);
    }
  });

  it('should return amount as payment value when in first period when start>now before activation', async () => {
    await utils.sleep(startDelay*1000);
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

  });

});
