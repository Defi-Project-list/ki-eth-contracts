const SW_Proxy = artifacts.require("SW_Proxy");
const SW_Factory = artifacts.require("SW_Factory");
const SW_FactoryProxy = artifacts.require("SW_FactoryProxy");
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

contract('SW_FactoryProxy', async accounts => {
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
    const sw_factory = await SW_Factory.new({ from: owner });
    const sw_factory_proxy = await SW_FactoryProxy.new({ from: owner });
    await sw_factory_proxy.setTarget(sw_factory.address, { from: owner });
    instance = await SW_Factory.at(sw_factory_proxy.address, { from: owner });

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

    await instance.addVersion(web3.fromAscii("1.1", 8), swver.address, { from: owner });

    await instance.createSmartWallet(false, { from: owner });
    let logs = await new Promise((r,j) => instance.allEvents({}, { fromBlock: 'latest', toBlock: 'latest' }).get((err, logs) => { r(logs) }));
    mlog.log('logs', JSON.stringify(logs[0]));

    const sw = await instance.getSmartWallet(owner);
    mlog.log('sw:', sw);

    const sw_proxy = await SW_Proxy.at(sw);

    const sw_creator = await sw_proxy.creator();
    mlog.log('creator:', sw_creator);

    const sw_target = await sw_proxy.target();
    mlog.log('target:', sw_target);

    const sw_owner = await sw_proxy.owner();
    mlog.log('owner:', sw_owner);

    await web3.eth.sendTransaction({ from: user2, value: val2, to: sw });

    logs = await new Promise((r,j) => sw_proxy.allEvents({}, { fromBlock: 'latest', toBlock: 'latest' }).get((err, logs) => { r(logs) }));
    mlog.log('logs', JSON.stringify(logs[0]));

    let swvalue = await SmartWallet.at(sw).getBalance();
    mlog.log('balance(proxy)', swvalue);
    //await SmartWallet.at(sw).setValue(12);
    await SmartWallet.at(sw).sendEther(user2, val2, {from: owner});
    swvalue = await SmartWallet.at(sw).getBalance();
    mlog.log('balance(proxy)', swvalue);

    /*
    await swver.setValue(12);
    await swver.setValue(235);
    const vervalue = await swver.getValue();
    mlog.log('value(direct)', vervalue);
    */
    const swver2 = await SmartWallet2.new();
    mlog.log('version2:', swver2.address);

    await instance.addVersion(web3.fromAscii("1.2", 8), swver2.address, { from: owner });

    await SmartWallet.at(sw).upgrade(web3.fromAscii("1.2", 8), {from: owner});

    await SmartWallet2.at(sw).setValue(235, 10, {from: owner});
    const swvalue2 = await SmartWallet2.at(sw).getValue();
    mlog.log('value(proxy)', swvalue2);
  });

  it ('should be able to create smart wallet', async () => {
    const swver = await SmartWallet.new();
    mlog.log('version:', swver.address);

    await instance.addVersion(web3.fromAscii("2.1", 8), swver.address, { from: owner });

    await instance.createSmartWallet(true, { from: user1 });
    let logs = await new Promise((r,j) => instance.allEvents({}, { fromBlock: 'latest', toBlock: 'latest' }).get((err, logs) => { r(logs) }));
    mlog.log('logs', JSON.stringify(logs[0]));


    const sw = await instance.getSmartWallet(user1);
    mlog.log('sw:', sw);

    //await SmartWallet.at(sw).upgrade(web3.fromAscii("latest", 8), {from: user1});

    const sw_proxy = await SW_Proxy.at(sw);

    const sw_creator = await sw_proxy.creator();
    mlog.log('creator:', sw_creator);

    const sw_target = await sw_proxy.target();
    mlog.log('target:', sw_target);

    const sw_owner = await sw_proxy.owner();
    mlog.log('owner:', sw_owner);

    await web3.eth.sendTransaction({ from: user2, value: val2, to: sw });

    logs = await new Promise((r,j) => sw_proxy.allEvents({}, { fromBlock: 'latest', toBlock: 'latest' }).get((err, logs) => { r(logs) }));
    mlog.log('logs', JSON.stringify(logs[0]));

    let swvalue = await SmartWallet.at(sw).getBalance();
    mlog.log('balance(proxy)', swvalue);
    //await SmartWallet.at(sw).setValue(12);
    await SmartWallet.at(sw).sendEther(user2, val2, {from: user1});
    swvalue = await SmartWallet.at(sw).getBalance();
    mlog.log('balance(proxy)', swvalue);

    const swver2 = await SmartWallet2.new();
    mlog.log('version2:', swver2.address);

    await instance.addVersion(web3.fromAscii("2.2", 8), swver2.address, { from: owner });

    /*await SmartWallet2.at(sw).setValue(235, 10, {from:user1});
    let swvalue2 = await SmartWallet2.at(sw).getValue();
    mlog.log('value(proxy)', swvalue2);
    */

    //await SmartWallet.at(sw).upgrade(web3.fromAscii("2.2", 8), {from: user1});

    await SmartWallet2.at(sw).setValue(235, 10, {from:user1, value:10000});
    swvalue2 = await SmartWallet2.at(sw).getValue();
    mlog.log('value(proxy)', swvalue2);

    logs = await new Promise((r,j) => sw_proxy.allEvents({}, { fromBlock: 'latest', toBlock: 'latest' }).get((err, logs) => { r(logs) }));
    mlog.log('logs', JSON.stringify(logs));

    await swver2.setValue(235, 10, {from:user1, value:10000});
    swvalue2 = await swver2.getValue();
    mlog.log('value', swvalue2);

    logs = await new Promise((r,j) => sw_proxy.allEvents({}, { fromBlock: 'latest', toBlock: 'latest' }).get((err, logs) => { r(logs) }));
    mlog.log('logs', JSON.stringify(logs));

  });

});
