'use strict';

const Wallet = artifacts.require("Wallet");
const Oracle = artifacts.require("Oracle");
const Factory = artifacts.require("Factory");
const FactoryProxy = artifacts.require("FactoryProxy");
const ERC20Token = artifacts.require("ERC20Token");
const ERC721Token = artifacts.require("ERC721Token");
const mlog = require('mocha-logger');
const {
  assertRevert,
  assertInvalidOpcode,
  assertPayable,
  assetEvent_getArgs
} = require('./lib/asserts');
contract('Wallet', async accounts => {
  let instance;
  let factory;
  let token20;
  let token20notSafe;
  let token721;
  let oracle;
  const creator = accounts[9];
  const owner   = accounts[0];
  const user1   = accounts[1];
  const user2   = accounts[2];
  const user3   = accounts[3];
  
  const val1  = web3.utils.toWei('0.5', 'gwei');
  const val2  = web3.utils.toWei('0.4', 'gwei');
  const val3  = web3.utils.toWei('0.6', 'gwei');
  const valBN = web3.utils.toBN(val1).add(web3.utils.toBN(val2)).add(web3.utils.toBN(val3));
  
  before('checking constants', async () => {
    assert(typeof creator == 'string', 'creator should be string');
    assert(typeof owner   == 'string', 'owner   should be string');
    assert(typeof user1   == 'string', 'user1   should be string');
    assert(typeof user2   == 'string', 'user2   should be string');
    assert(typeof val1    == 'string', 'val1    should be string');
    assert(typeof val2    == 'string', 'val2    should be string');
    assert(typeof val3    == 'string', 'val2    should be string');
    assert(valBN instanceof web3.utils.BN, 'valBN should be big number');
  });
  
  before('setup contract for the test', async () => {
    const sw_factory = await Factory.new({ from: creator, nonce: await web3.eth.getTransactionCount(creator) });
    const sw_factory_proxy = await FactoryProxy.new({ from: creator });
    await sw_factory_proxy.setTarget(sw_factory.address, { from: creator });
    factory = await Factory.at(sw_factory_proxy.address, { from: creator });
    
    //const factory = await FactoryProxy.new({ from: creator });
    const version = await Wallet.new({ from: creator });
    oracle = await Oracle.new(owner, user1, user2, {from: owner, nonce: await web3.eth.getTransactionCount(owner)});
    await oracle.setPaymentAddress(user1, { from: owner });
    await oracle.setPaymentAddress(user1, { from: user1 });
    //await factory.addVersion(web3.fromAscii("1.1", 8), version.address, { from: creator });
    await factory.addVersion(version.address, oracle.address, { from: creator });
    await factory.deployVersion(await version.version(), { from: creator });
    await factory.createWallet(false, { from: owner });
    instance = await Wallet.at( await factory.getWallet(owner) );

    token20 = await ERC20Token.new('Kirobo ERC20 Token', 'KDB20', {from: owner});
    await oracle.update721(token20.address, true, {from: user1});
    await oracle.cancel({from: user2});
    await oracle.update20(token20.address, true, {from: user2});
    await oracle.update20(token20.address, true, {from: user1});
    token20notSafe = await ERC20Token.new('Kirobo ERC20 Not Safe Token', 'KDB20NS', {from: owner});
    token721 = await ERC721Token.new('Kirobo ERC721 Token', 'KBF', {from: owner});
    mlog.log('web3      ', web3.version);
    mlog.log('token20   ', token20.address);
    mlog.log('token20ns ', token20.address);
    mlog.log('token721  ', token20.address);
    mlog.log('factory   ', factory.address);
    mlog.log('wallet    ', instance.address);
    mlog.log('owner     ', owner);
    mlog.log('user1     ', user1);
    mlog.log('user2     ', user2);
    mlog.log('val1      ', val1);
    mlog.log('val2      ', val2);
    mlog.log('val3      ', val3);
  });
  
  it('should create empty wallet', async () => {
    const balance = await web3.eth.getBalance(instance.address);
    assert.equal(balance.toString(10), web3.utils.toBN('0').toString(10));
    await web3.eth.sendTransaction({ from: owner, value: val2, to: instance.address });
    await instance.sendEther(user1, val2, { from: owner });
  });

  it('should accept ether from everyone', async () => {
    await web3.eth.sendTransaction({ from: owner, value: val1, to: instance.address, nonce: await web3.eth.getTransactionCount(owner) });
    await web3.eth.sendTransaction({ from: user1, value: val2, to: instance.address, nonce: await web3.eth.getTransactionCount(user1) });
    await web3.eth.sendTransaction({ from: user2, value: val3, to: instance.address, nonce: await web3.eth.getTransactionCount(user2) });
    
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
    await instance.sendEther(user2, val1, { from: owner });
    const userBalanceAfter = await web3.eth.getBalance(user2);
    mlog.log('before', userBalanceBefore)
    mlog.log('after', userBalanceAfter)
    const userBalanceDelta = web3.utils.toBN(userBalanceAfter).sub(web3.utils.toBN(userBalanceBefore));
    mlog.log('delta', userBalanceDelta)
    assert.equal(userBalanceDelta.toString(10), val1);
    
    try {
      await instance.sendEther(user2, val1, { from: user1 });
      assert(false);
    } catch (err) {
      assertRevert(err);
    }
    
  });
  
  it('should not allow sendEther to be payable', async () => {
    const contractBalanceBefore = await web3.eth.getBalance(instance.address);
    try {
      await instance.sendEther(owner, val1, { from: owner, value: val1 });
      assert(false);
    } catch (err) {
      assertPayable(err);
    }
    const contractBalanceAfter = await web3.eth.getBalance(instance.address);
    const contractBalanceDelta = web3.utils.toBN(contractBalanceBefore).sub(web3.utils.toBN(contractBalanceAfter));
    assert.equal(contractBalanceDelta.toString(10), web3.utils.toBN('0').toString(10));
  });

  it('should send ether from the contract when calling sendEther', async() => {
    const contractBalanceBefore = await web3.eth.getBalance(instance.address);
    const walletBalanceBefore = await instance.getBalance.call({ from: owner });
    
    await instance.sendEther(user2, val2, { from: owner, nonce: await web3.eth.getTransactionCount(owner) });
    
    const contractBalanceAfter = await web3.eth.getBalance(instance.address);
    const walletBalanceAfter = await instance.getBalance.call({ from: owner });
    
    const contractBalanceDelta = web3.utils.toBN(contractBalanceBefore).sub(web3.utils.toBN(contractBalanceAfter));
    const walletBalanceDelta = web3.utils.toBN(walletBalanceBefore.sub(web3.utils.toBN(walletBalanceAfter)));
    
    assert.equal(contractBalanceDelta, val2);
    assert.equal(walletBalanceDelta, val2);
  });
  

  it ('should emit event "GotEther(from, value)" when getting ether', async () => {
    const tx = await web3.eth.sendTransaction({ from: user2, value: val3, to: instance.address, nonce: await web3.eth.getTransactionCount(user2) });
    mlog.log('logs', JSON.stringify(tx.logs)); // TODO: parse low level log and add assets
    //assert.equal(args.owner, owner, '..(owner, ..)');
    
    // const logs = await new Promise((r, j) => web3.eth.filter({
      //       address: instance.address,
      //       fromBlock: 'latest',
      //       toBlock: 'latest',
      //       topics: ['0x0000000000000000000000000000000000000000000000000000000000000001']
      //     })
      //     .get((err, logs) => { r(logs) }));
      //     mlog.log('logs', JSON.stringify(logs));
      //     /*
    //     //const args = assetEvent_getArgs(logs, '0x');
    //     //assert.equal (args.from, user2, '..(from, ..)');
    //     //assert.equal (args.value, val3, '..(.. ,value)');
    //     */
  });
      
  it ('should emit event "SentEther(to, value)" when calling sendEther', async () => {
    const tx = await instance.sendEther(user1, val2, { from: owner, nonce: await web3.eth.getTransactionCount(owner) });
    const args = assetEvent_getArgs(tx.logs, 'SentEther');
    assert.equal (args.to, user1, '..(to, ..)');
    assert.equal (args.value, val2, '..(.. ,value)');
  });

  it ('should be able to send erc20 tokens to wallet', async () => {
    await token20.mint(user1, 1000, { from: owner, nonce: await web3.eth.getTransactionCount(owner) });
    await token20.transfer(instance.address, 50, {from: user1, nonce: await web3.eth.getTransactionCount(user1)});
    
    let balance = await token20.balanceOf(user1, {from: user1});
    assert.equal (balance.toNumber(), 950, 'user1 balance');
    balance = await instance.balanceOf20(token20.address);
    assert.equal (balance.toNumber(), 50, 'wallet balance');
  });

  it ('should be able to send erc20 tokens from wallet', async () => {
    await instance.transfer20(token20.address, user2, 20, { from: owner});
    
    let balance = await token20.balanceOf(instance.address, {from: owner});
    assert.equal (balance.toNumber(), 30, 'wallet balance (native)');
    balance = await instance.balanceOf20(token20.address, {from: owner});
    assert.equal (balance.toNumber(), 30, 'wallet balance');
    balance = await token20.balanceOf(user2, {from: user2});
    assert.equal (balance.toNumber(), 20, 'wallet balance');
  });
  
  it ('token20 should be safe to use', async () => {
    const isTokenSafe = await instance.is20Safe(token20.address, { from: owner});
    assert.equal (isTokenSafe, true, "is token20 safe");
  });
  
  it ('token20notSafe should not be safe to use', async () => {
    const isTokenSafe = await instance.is20Safe(token20notSafe.address, { from: owner});
    assert.equal (isTokenSafe, false, "is token20notSafe safe");
  });
  
  it ('should be able to send erc721 token to wallet', async () => {
    await token721.createTimeframe("https://example.com/doggo.json" , { from: owner});
    await token721.createTimeframe("https://example.com/doggo2.json" , { from: owner});
    await token721.createTimeframe("https://example.com/doggo3.json" , { from: owner});
    await token721.createTimeframe("https://example.com/doggo4.json" , { from: owner});
    await token721.transferFrom(owner, instance.address, 1, {from: owner});
    await token721.safeTransferFrom(owner, instance.address, 2, {from: owner});
    await token721.approve(instance.address, 3, { from: owner });
    await token721.approve(instance.address, 4, { from: owner });
    await token721.transferFrom(owner, instance.address, 3, {from: owner});
    await token721.safeTransferFrom(owner, instance.address, 4, {from: owner});
  });

  it ('should be able to send erc721 token from wallet', async () => {
    await instance.transfer721(token721.address, user1, 1, {from: owner});
    await instance.transfer721(token721.address, user1, 2, {from: owner});
    await instance.transfer721(token721.address, user2, 3, {from: owner});
    await instance.transfer721(token721.address, user2, 4, {from: owner});
  });
  
});
