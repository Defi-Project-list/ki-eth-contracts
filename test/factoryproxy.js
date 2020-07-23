'use strict';

const Proxy = artifacts.require("Proxy");
const Factory = artifacts.require("Factory");
const FactoryProxy = artifacts.require("FactoryProxy");
const Wallet = artifacts.require("Wallet");
const Oracle = artifacts.require("Oracle");
const Wallet2 = artifacts.require("Wallet2");
const Oracle2 = artifacts.require("Oracle2");
const Sender = artifacts.require("Sender");
const mlog = require('mocha-logger');
const {
  assertRevert,
  assertInvalidOpcode,
  assertPayable,
  assetEvent_getArgs
} = require('./lib/asserts');

contract('FactoryProxy', async accounts => {
  let instance;

  const owner = accounts[0];
  const user1 = accounts[1];
  const user2 = accounts[2];

  const val1  = web3.utils.toWei('0.5', 'gwei');
  const val2  = web3.utils.toWei('0.4', 'gwei');
  const val3  = web3.utils.toWei('0.6', 'gwei');
  const valBN = web3.utils.toBN('0'); //val1).add(web3.utils.toBN(val2)).add(web3.utils.toBN(val3));

  before('checking constants', async () => {
      assert(typeof owner == 'string', 'owner should be string');
      assert(typeof user1 == 'string', 'user1 should be string');
      assert(typeof user2 == 'string', 'user2 should be string');
      assert(typeof val1  == 'string', 'val1  should be string');
      assert(typeof val2  == 'string', 'val2  should be string');
      assert(typeof val3  == 'string', 'val2  should be string');
      assert(valBN instanceof web3.utils.BN, 'valBN should be big number');
  });

  before('setup contract for the test', async () => {
    const sw_factory = await Factory.new({ from: owner, nonce: await web3.eth.getTransactionCount(owner) });
    const sw_factory_proxy = await FactoryProxy.new({ from: owner });
    await sw_factory_proxy.setTarget(sw_factory.address, { from: owner });
    instance = await Factory.at(sw_factory_proxy.address, { from: owner });

    mlog.log('web3     ', web3.version);
    mlog.log('contract ', instance.address);
    mlog.log('owner    ', owner);
    mlog.log('user1    ', user1);
    mlog.log('user2    ', user2);
    mlog.log('val1     ', val1);
    mlog.log('val2     ', val2);
    mlog.log('val3     ', val3);
  });

  it('should create empty factory', async () => {
    const balance = await web3.eth.getBalance(instance.address);
    assert.equal(balance.toString(10), web3.utils.toBN('0').toString(10));
  });

  it.skip ('should be able to create a wallet', async () => {
    const swver = await Wallet.new({ from: owner, nonce: await web3.eth.getTransactionCount(owner) });
    const oracle = await Oracle.new(owner, user1, user2, {from: owner});
    await oracle.setPaymentAddress(user1, { from: owner });
    await oracle.setPaymentAddress(user1, { from: user1 });

    mlog.log('version:', swver.address);

    //await instance.addVersion(web3.fromAscii("1.1", 8), swver.address, { from: owner });
    await instance.addVersion(swver.address, oracle.address, { from: owner });
    await instance.deployVersion(await swver.version(), { from: owner });

    await instance.createWallet(false, { from: owner });
    let logs = await instance.allEvents({ fromBlock: 'latest', toBlock: 'latest' })
    mlog.log('logs', JSON.stringify(logs[0]));

    const sw = await instance.getWallet(owner);
    mlog.log('sw:', sw);

    const sw_proxy = await Proxy.at(sw);

    const sw_creator = await sw_proxy.creator();
    mlog.log('creator:', sw_creator);

    const sw_target = await sw_proxy.target();
    mlog.log('target:', sw_target);

    const sw_owner = await sw_proxy.owner();
    mlog.log('owner:', sw_owner);

    await web3.eth.sendTransaction({ from: user2, value: val2, to: sw, nonce: await web3.eth.getTransactionCount(user2) });

    logs = await sw_proxy.allEvents({ fromBlock: 'latest', toBlock: 'latest' })
    mlog.log('logs', JSON.stringify(logs[0]));

    let swvalue = await (await Wallet.at(sw)).getBalance();
    mlog.log('balance(proxy)', swvalue);
    //await Wallet.at(sw).setValue(12);
    await (await Wallet.at(sw)).sendEther(user2, val2, {from: owner});
    swvalue = await (await Wallet.at(sw)).getBalance();
    mlog.log('balance(proxy)', swvalue);

    /*
    await swver.setValue(12);
    await swver.setValue(235);
    const vervalue = await swver.getValue();
    mlog.log('value(direct)', vervalue);
    */
    const swver2 = await Wallet2.new({from: owner});
    const oracle2 = await Oracle2.new({from: owner});
    await oracle2.setPaymentAddress(owner, { from:owner })
    mlog.log('version2:', swver2.address);

    //await instance.addVersion(web3.fromAscii("1.2", 8), swver2.address, { from: owner });
    await instance.addVersion(swver2.address, { from: owner });
    await instance.deployVersion(await swver2.version(), { from: owner });

    await (await Wallet.at(sw)).upgrade(web3.fromAscii("1.2", 8), {from: owner});

    await (await Wallet2.at(sw)).setValue(235, 10, {from: owner});
    const swvalue2 = await (await Wallet2.at(sw)).getValue();
    mlog.log('value(proxy)', swvalue2);
  });

  it ('should be able to create a wallet', async () => {
    
    const swver = await Wallet.new({ from: owner, nonce: await web3.eth.getTransactionCount(owner) });
    const oracle = await Oracle.new(owner, user1, user2, {from: owner});
    await oracle.setPaymentAddress(user1, { from: owner });
    await oracle.setPaymentAddress(user1, { from: user1 });

    mlog.log('version:', swver.address);

    //await instance.addVersion(web3.fromAscii("2.1", 8), swver.address, { from: owner });
    await instance.addVersion(swver.address, oracle.address, { from: owner });
    await instance.deployVersion(await swver.version(), { from: owner });

    let tx = await instance.createWallet(true, { from: user1, nonce: await web3.eth.getTransactionCount(user1) });
    // let logs = await new Promise((r,j) => instance.allEvents({}, { fromBlock: 'latest', toBlock: 'latest' }).get((err, logs) => { r(logs) }));
    let logs = await instance.allEvents({ fromBlock: 'latest', toBlock: 'latest' })
    mlog.log('logs', JSON.stringify(tx.logs[0]));


    const sw_user1 = await instance.getWallet(user1);
    mlog.log('sw_user1:', sw_user1);

    //await Wallet.at(sw).upgrade(web3.fromAscii("latest", 8), {from: user1});

    const sw_proxy = await Proxy.at(sw_user1);

    const sw_creator = await sw_proxy.creator();
    mlog.log('creator:', sw_creator);

    const sw_target = await sw_proxy.target();
    mlog.log('target:', sw_target);

    const sw_owner = await sw_proxy.owner();
    mlog.log('owner:', sw_owner);

    tx = await web3.eth.sendTransaction({ from: user2, value: val2, to: sw_user1, nonce: await web3.eth.getTransactionCount(user2) });

    //logs = await new Promise((r,j) => sw_proxy.allEvents({}, { fromBlock: 'latest', toBlock: 'latest' }).get((err, logs) => { r(logs) }));
    logs = await sw_proxy.allEvents({ fromBlock: 'latest', toBlock: 'latest' })
    mlog.log('logs', JSON.stringify(tx.logs[0]));

    let swvalue = await (await Wallet.at(sw_user1)).getBalance();
    mlog.log('balance(proxy)', swvalue);
    //await Wallet.at(sw).setValue(12);
    await (await Wallet.at(sw_user1)).sendEther(user2, val2, {from: user1});
    swvalue = await (await Wallet.at(sw_user1)).getBalance();
    mlog.log('balance(proxy)', swvalue);

    const swver2 = await Wallet2.new({ from: owner });
    const oracle2 = await Oracle2.new(owner, user1, user2, {from: owner});
    await oracle2.setPaymentAddress(owner, {from: owner});
    await oracle2.setPaymentAddress(owner, {from: user1});

    mlog.log('version2:', swver2.address);

    tx = await instance.createWallet(true, { from: user2 });
    //logs = await new Promise((r,j) => instance.allEvents({}, { fromBlock: 'latest', toBlock: 'latest' }).get((err, logs) => { r(logs) }));
    logs = await instance.allEvents({ fromBlock: 'latest', toBlock: 'latest' })
    mlog.log('logs', JSON.stringify(tx.logs[0]));

    let sw_user2 = await instance.getWallet(user2);
    mlog.log('sw_user2:', sw_user2);
    let isUser2Owner = await (await Wallet.at(sw_user1)).isOwner({from : user2});
    mlog.log('user2 is owner of sw_user1:', isUser2Owner);
    isUser2Owner = await (await Wallet.at(sw_user2)).isOwner({from : user2});
    mlog.log('user2 is owner of sw_user2:', isUser2Owner);

    let isUser1Owner = await (await Wallet.at(sw_user1)).isOwner({from : user1});
    mlog.log('user1 is owner of sw_user1:', isUser1Owner);
    isUser1Owner = await (await Wallet.at(sw_user2)).isOwner({from : user1});
    mlog.log('user1 is owner of sw_user2:', isUser1Owner);
    //await instance.addVersion(web3.fromAscii("2.2", 8), swver2.address, { from: owner });
    await instance.addVersion(swver2.address, oracle2.address, { from: owner });
    await instance.deployVersion(await swver2.version(), { from: owner });

    /*await Wallet2.at(sw).setValue(235, 10, {from:user1});
    let swvalue2 = await Wallet2.at(sw).getValue();
    mlog.log('value(proxy)', swvalue2);
    */

    //await Wallet.at(sw).upgrade(web3.fromAscii("2.2", 8), {from: user1});

    await (await Wallet2.at(sw_user1)).setValue(235, 10, {from:user1, value:10000});
    let swvalue2 = await (await Wallet2.at(sw_user1)).getValue();
    mlog.log('value(proxy)', swvalue2);

    //logs = await new Promise((r,j) => sw_proxy.allEvents({ fromBlock: 'latest', toBlock: 'latest' }).get((err, logs) => { r(logs) }));
    logs = await sw_proxy.allEvents({ fromBlock: 'latest', toBlock: 'latest',
          topics: ['0x0000000000000000000000000000000000000000000000000000000000000002']})
    //logs = await new Promise((r, j) => web3.eth.filter({ address: sw_proxy.address, fromBlock: 'latest', toBlock: 'latest',
    //      topics: [null, null,'0x7b8d56e300000000000000000000000000000000000000000000000000000000']}).get((err, logs) => { r(logs) }));

    mlog.log('logs', JSON.stringify(logs));

    await swver2.setValue(235, 10, {from:owner, value:10000});
    swvalue2 = await swver2.getValue();
    mlog.log('value', swvalue2);

    logs = await sw_proxy.allEvents({ fromBlock: '0', toBlock: 'latest' })
    mlog.log('logs', JSON.stringify(logs));

    let bal = await web3.eth.getBalance(sw_user1);
    mlog.log('sw balance before: ', bal.toString(10));

    const sender = await Sender.new({from: user2});
    await web3.eth.sendTransaction({ from: user2, value: web3.utils.toWei('50', 'gwei'), to: sender.address });

    bal = await web3.eth.getBalance(sender.address);
    mlog.log('sender balance before: ', bal.toString(10));

    await sender.sendEther(sw_user1, 300, {from: user2});

    bal = await web3.eth.getBalance(sw_user1);
    mlog.log('sw balance after: ', bal.toString(10));

  });

});
