const SWProxy = artifacts.require("SWProxy");
const SWProxyFactory = artifacts.require("SWProxyFactory");
const SmartWallet = artifacts.require("SmartWallet");
const SmartWallet2 = artifacts.require("SmartWallet2");
const mlog = require('mocha-logger');
const {
  assertRevert,
  assertInvalidOpcode,
  assertPayable,
  assetEvent_getArgs
} = require('./lib/asserts');

console.log("Using web3 '" + web3.version.api + "'");

contract('SWProxyFactory', async accounts => {
  let instance;

  const owner = accounts[0];
  const user1 = accounts[1];
  const user2 = accounts[2];

  const val1  = web3.toWei(0.5, 'gwei');
  const val2  = web3.toWei(0.4, 'gwei');
  const val3  = web3.toWei(0.6, 'gwei');
  const valBN = web3.toBigNumber(val1).add(web3.toBigNumber(val2)).add(web3.toBigNumber(val3));

  before('checking constants', async () => {
      assert(typeof owner == 'string', 'owner should be string');
      assert(typeof user1 == 'string', 'user1 should be string');
      assert(typeof user2 == 'string', 'user2 should be string');
      assert(typeof val1  == 'string', 'val1  should be string');
      assert(typeof val2  == 'string', 'val2  should be string');
      assert(typeof val3  == 'string', 'val2  should be string');
      assert(valBN instanceof web3.BigNumber, 'valBN should be big number');
  });

  before('setup contract for the test', async () => {
    instance = await SWProxyFactory.new();

    mlog.log('contract  ', instance.address);
    mlog.log('owner   ', owner);
    mlog.log('user1   ', user1);
    mlog.log('user2   ', user2);
    mlog.log('val1    ', val1);
    mlog.log('val2    ', val2);
    mlog.log('val3    ', val3);
  });

  it('should create empty factory', async () => {
    const balance = await web3.eth.getBalance(instance.address);
    assert.equal(balance.toString(10), web3.toBigNumber(0).toString(10));
  });

  it ('should be able to create smart wallet', async () => {
    const swver = await SmartWallet.new();
    mlog.log('version:', swver.address);

    await instance.clone(swver.address, { from: owner });

    const sw = await instance.clones(owner);
    mlog.log('sw:', sw);

    const sw_proxy = await SWProxy.at(sw);
    const sw_creator = await sw_proxy.creator();
    mlog.log('creator:', sw_creator);

    const sw_target = await sw_proxy.target();
    mlog.log('target:', sw_target);

    const sw_owner = await sw_proxy.owner();
    mlog.log('owner:', sw_owner);

    await web3.eth.sendTransaction({ from: user2, value: val2, to: sw });

    const logs = await new Promise((r,j) => sw_proxy.allEvents({}, { fromBlock: 'latest', toBlock: 'latest' }).get((err, logs) => { r(logs) }));
    mlog.log('logs', JSON.stringify(logs[0]));

    await SmartWallet.at(sw).setValue(12);
    await SmartWallet.at(sw).setValue(235);
    const swvalue = await SmartWallet.at(sw).getValue();
    mlog.log('value(proxy)', swvalue);

    await swver.setValue(12);
    await swver.setValue(235);
    const vervalue = await swver.getValue();
    mlog.log('value(direct)', vervalue);

    const swver2 = await SmartWallet2.new();
    mlog.log('version2:', swver2.address);

    await SmartWallet.at(sw).setTarget(swver2.address);

    await SmartWallet2.at(sw).setValue(235, 10);
    const swvalue2 = await SmartWallet2.at(sw).getValue();
    mlog.log('value(proxy)', swvalue2);



  });


});
