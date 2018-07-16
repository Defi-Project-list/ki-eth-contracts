const SmartWallet = artifacts.require("SmartWallet");
const SW_Factory = artifacts.require("SW_Factory");
const SW_FactoryProxy = artifacts.require("SW_FactoryProxy");
const mlog = require('mocha-logger');
const {
  assertRevert,
  assertInvalidOpcode,
  assertPayable,
  assetEvent_getArgs
} = require('./lib/asserts');

//const truffleAssert = require('truffle-assertions');

console.log("Using web3 '" + web3.version.api + "'");

contract('SmartWallet', async accounts => {
  let instance;

  const creator = accounts[9];
  const owner   = accounts[0];
  const user1   = accounts[1];
  const user2   = accounts[2];

  const val1  = web3.toWei(0.5, 'gwei');
  const val2  = web3.toWei(0.4, 'gwei');
  const val3  = web3.toWei(0.6, 'gwei');
  const valBN = web3.toBigNumber(val1).add(web3.toBigNumber(val2)).add(web3.toBigNumber(val3));

  before('checking constants', async () => {
      assert(typeof creator == 'string', 'creator should be string');
      assert(typeof owner   == 'string', 'owner   should be string');
      assert(typeof user1   == 'string', 'user1   should be string');
      assert(typeof user2   == 'string', 'user2   should be string');
      assert(typeof val1    == 'string', 'val1    should be string');
      assert(typeof val2    == 'string', 'val2    should be string');
      assert(typeof val3    == 'string', 'val2    should be string');
      assert(valBN instanceof web3.BigNumber, 'valBN should be big number');
  });

  before('setup contract for the test', async () => {
    const sw_factory = await SW_Factory.new({ from: creator });
    const sw_factory_proxy = await SW_FactoryProxy.new({ from: creator });
    await sw_factory_proxy.setTarget(sw_factory.address, { from: creator });
    const factory = await SW_Factory.at(sw_factory_proxy.address, { from: creator });

    //const factory = await SW_FactoryProxy.new({ from: creator });
    const version = await SmartWallet.new({ from: creator });
    //await factory.addVersion(web3.fromAscii("1.1", 8), version.address, { from: creator });
    await factory.addVersion(version.address, { from: creator });
    await factory.createSmartWallet(false, { from: owner });
    instance = await SmartWallet.at( await factory.getSmartWallet(owner) );

    mlog.log('wallet  ', instance.address);
    mlog.log('owner   ', owner);
    mlog.log('user1   ', user1);
    mlog.log('user2   ', user2);
    mlog.log('val1    ', val1);
    mlog.log('val2    ', val2);
    mlog.log('val3    ', val3);
  });

  it('should create empty wallet', async () => {
    const balance = await web3.eth.getBalance(instance.address);
    assert.equal(balance.toString(10), web3.toBigNumber(0).toString(10));
  });

  it('should accept ether from everyone', async () => {
    await web3.eth.sendTransaction({ from: owner, value: val1, to: instance.address });
    await web3.eth.sendTransaction({ from: user1, value: val2, to: instance.address });
    await web3.eth.sendTransaction({ from: user2, value: val3, to: instance.address });

    const balance = await web3.eth.getBalance(instance.address);
    assert.equal(balance.toString(10), valBN.toString(10));
  });

  /*it('only owner can call getBalance', async () => {
    const balance = await instance.getBalance.call({
      from: owner
    });
    assert.equal(balance.toString(10), valBN.toString(10));
    try {
      const balance = await instance.getBalance.call({
        from: user1
      });
      assert(false);
    } catch (err) {
      assertRevert(err);
    }
  });*/

  it('only owner can send ether', async () => {
    const userBalanceBefore = await web3.eth.getBalance(user2);
    await instance.sendEther(user2, web3.toBigNumber(val1), { from: owner });
    const userBalanceAfter = await web3.eth.getBalance(user2);
    const userBalanceDelta = userBalanceAfter.sub(userBalanceBefore);
    assert.equal(userBalanceDelta, val1);

    try {
      await instance.sendEther(user2, web3.toBigNumber(val1), { from: user1 });
      assert(false);
    } catch (err) {
      assertRevert(err);
    }

  });

  it('should not allow sendEther to be payable', async () => {
    const contractBalanceBefore = await web3.eth.getBalance(instance.address);
    try {
      await instance.sendEther(owner, web3.toBigNumber(val1), { from: owner, value: val1 });
      assert(false);
    } catch (err) {
      assertPayable(err);
    }
    const contractBalanceAfter = await web3.eth.getBalance(instance.address);
    const contractBalanceDelta = contractBalanceBefore.sub(contractBalanceAfter);
    assert.equal(contractBalanceDelta, web3.toBigNumber(0).toString(10));
  });

  it('should send ether from the contract when calling sendEther', async() => {
    const contractBalanceBefore = await web3.eth.getBalance(instance.address);
    const walletBalanceBefore = await instance.getBalance.call({ from: owner });

    await instance.sendEther(user2, web3.toBigNumber(val2), { from: owner });

    const contractBalanceAfter = await web3.eth.getBalance(instance.address);
    const walletBalanceAfter = await instance.getBalance.call({ from: owner });

    const contractBalanceDelta = contractBalanceBefore.sub(walletBalanceAfter);
    const walletBalanceDelta = walletBalanceBefore.sub(walletBalanceAfter);

    assert.equal(contractBalanceDelta, val2);
    assert.equal(walletBalanceDelta, val2);
  });


  it ('should emit event "GotEther(from, value)" when getting ether', async () => {
    await web3.eth.sendTransaction({ from: user2, value: val3, to: instance.address });

    const logs = await new Promise((r, j) => web3.eth.filter({
          address: instance.address,
          fromBlock: 'latest',
          toBlock: 'latest',
          topics: ['0x0000000000000000000000000000000000000000000000000000000000000001']
        })
    .get((err, logs) => { r(logs) }));
    mlog.log('logs', JSON.stringify(logs));
    //const args = assetEvent_getArgs(logs, '0x');
    //assert.equal (args.from, user2, '..(from, ..)');
    //assert.equal (args.value, val3, '..(.. ,value)');
  });

  it ('should emit event "SentEther(to, value)" when calling sendEther', async () => {
    await instance.sendEther(user1, val2, { from: owner });

    const logs = await new Promise((r,j) => instance.SentEther({}, { fromBlock: 'latest', toBlock: 'latest' })
    .get((err, logs) => { r(logs) }));
    mlog.log('logs', JSON.stringify(logs));

    const args = assetEvent_getArgs(logs, 'SentEther');
    assert.equal (args.to, user1, '..(to, ..)');
    assert.equal (args.value, val2, '..(.. ,value)');
  });


});
