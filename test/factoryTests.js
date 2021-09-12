'use strict';

const Wallet = artifacts.require("Wallet");
const Oracle = artifacts.require("Oracle");
const Wallet2 = artifacts.require("Wallet2");
const Oracle2 = artifacts.require("Oracle2");
const Proxy = artifacts.require("Proxy");
const Factory = artifacts.require("Factory");
const FactoryProxy = artifacts.require("FactoryProxy");

const mlog = require('mocha-logger');
const { ZERO_ADDRESS, ZERO_BYTES8, ZERO_BYTES32, ZERO_BN } = require('./lib/consts');
const {
  assertRevert,
  assertPayable,
  assertInvalidOpcode,
  assertFunction,
  assetEvent_getArgs
} = require('./lib/asserts');

const utils = require('./lib/utils');

module.exports = (contractClass, contractName) => {

contract (contractName, async accounts => {
  let instance;

  const owner1 = accounts[0];
  const owner2 = accounts[1];
  const owner3 = accounts[2];
  const user1  = accounts[3];
  const user2  = accounts[4];
  const user3  = accounts[5];

  let latestWallet  = null;
  let blockTimestamp = 0;

  before ('checking constants', async () => {
      assert(typeof owner1 == 'string', 'owner1 should be string');
      assert(typeof owner2 == 'string', 'owner2 should be string');
      assert(typeof owner3 == 'string', 'owner3 should be string');
      assert(typeof user1 == 'string', 'user1 should be string');
      assert(typeof user2 == 'string', 'user2 should be string');
      assert(typeof user3 == 'string', 'user3 should be string');
  });

  before ('setup contract for the test', async () => {
    if (contractClass.new instanceof Function) {
      //let instance = await Factory.new({from:"0xc8BB419F44D0C888B1dFF3863f889B8b8747f56b", nonce: await web3.eth.getTransactionCount("0xc8BB419F44D0C888B1dFF3863f889B8b8747f56b")})
      //instance = await contractClass.new({ from: "0x398626417A3F334dbf13762794d69715b56E4D2b", nonce: await web3.eth.getTransactionCount("0x398626417A3F334dbf13762794d69715b56E4D2b")});
  	   instance = await contractClass.new(/*owner1, owner2, owner3,*/ { from: owner1, nonce: await web3.eth.getTransactionCount(owner1)});
       // await instance.migrate();
 	} else {
  	   instance = await contractClass(/*owner1, owner2, owner3*/{ from: owner1, nonce: await web3.eth.getTransactionCount(owner1)});
    }

    mlog.log('web3     ', web3.version);
    mlog.log('contract ', instance.address);
    mlog.log('owner1   ', owner1);
    mlog.log('owner2   ', owner2);
    mlog.log('owner3   ', owner3);
    mlog.log('user1    ', user1);
    mlog.log('user2    ', user2);
    mlog.log('user3    ', user3);
  });

  it ('constructor: contract owners should be owners', async () => {
    assert(await instance.isOwner.call({from: owner1}));
    //assert(await instance.isOwner.call({from: owner2}));
    //assert(await instance.isOwner.call({from: owner3}));
    assert(!await instance.isOwner.call({from: user1}));
  });
  
  it ('constructor: latest wallet version should not exist', async () => {
    const latestWalletVersion = await instance.getLatestVersion.call({from: owner1});
    assert.equal(latestWalletVersion, ZERO_ADDRESS);
  });

  it ('constructor: user1 should not have a wallet', async () => {
    const wallet = await instance.getWallet.call(user1, {from: owner1});
    assert.equal(wallet, ZERO_ADDRESS);
  });

  it ('user cannot create a wallet when there is no wallet version', async () => {
    try {
      await instance.createWallet(true, {from: user1, nonce: await web3.eth.getTransactionCount(user1) });
      assert(false);
    } catch (err) {
      assertRevert(err);
    }    
    try {
      await instance.createWallet(false, {from: user1, nonce: await web3.eth.getTransactionCount(user1) });
      assert(false);
    } catch (err) {
      assertRevert(err);
    }    
  });

  it ('only owners can add wallet versions', async () => {
    const wallet_owner = await Wallet.new({from: owner1, nonce: await web3.eth.getTransactionCount(owner1)});
    const oracle_owner = await Oracle.new(owner1, owner2, owner3, {from: owner1});
    await oracle_owner.setPaymentAddress(owner2, { from: owner1 });
    await oracle_owner.setPaymentAddress(owner2, { from: owner2 });

    const wallet_user = await Wallet.new({from : user1, nonce: await web3.eth.getTransactionCount(user1)});
    const oracle_user = await Oracle.new(user1, user2, user3, {from: user1});
    await oracle_user.setPaymentAddress(user1, { from: user1 });
    await oracle_user.setPaymentAddress(user1, { from: user2 });

    try {
      await instance.addVersion(wallet_user.address, oracle_user.address, {from: user3});
      assert(false);
    } catch (err) {
      assertRevert(err);
    }
    try {
      await instance.addVersion(wallet_owner.address, oracle_owner.address, {from: user3, nonce: await web3.eth.getTransactionCount(user3)});
      assert(false);
    } catch (err) {
      assertRevert(err);
    }
    // try {
    //    await instance.addVersion (wallet_user.address, oracle_user.address, { from: owner1, nonce: await web3.eth.getTransactionCount(owner1) });
    //    assert(false);
    //  } catch (err) {
    //    assertRevert(err);
    //  }
    await instance.addVersion (wallet_owner.address, oracle_owner.address, { from: owner1, nonce: await web3.eth.getTransactionCount(owner1)});
    //await instance.addVersion (wallet_owner.address, oracle_owner.address, { from: owner3, nonce: await web3.eth.getTransactionCount(owner3)});
    await instance.deployVersion(await wallet_owner.version(), { from: owner1 }); 
    //await instance.deployVersion(await wallet_owner.version(), { from: owner2 }); 

    const version = await instance.getLatestVersion ({ from: owner1 });
    assert.equal (wallet_owner.address, version);
    latestWallet = wallet_owner;
  });

  it ('user can create a wallet in auto mode when version exists', async () => {
    await instance.createWallet (true, { from : user1, nonce: await web3.eth.getTransactionCount(user1) });
    const walletAddress = await instance.getWallet (user1, { from: user1, nonce: await web3.eth.getTransactionCount(user1) });
    mlog.log('wallet:', walletAddress);
    const wallet = await Wallet.at (walletAddress);
    const isUser1WalletOwner = await wallet.isOwner ({ from: user1 });
    const walletOwner = await wallet.owner ({ from: user1 });
    const sw_proxy = await Proxy.at(walletAddress);
    const sw_creator = await sw_proxy.creator();
    const sw_target = await sw_proxy.target();
    mlog.log('target:', sw_target);
    mlog.log('user1 is wallet owner:', isUser1WalletOwner);
    mlog.log('wallet owner:', walletOwner);
    mlog.log('wallet creator:', sw_creator);
    assert.ok (isUser1WalletOwner, 'user1 is wallet owner');
  });

  it ('users wallet always points to the latest version when in auto mode', async () => {
    let latestVersionAddress = await instance.getLatestVersion ({ from: owner1 });
    console.log("latestVersionAddress", latestVersionAddress)
    const walletAddress = await instance.getWallet (user1, { from: user1 });
    console.log("walletAddress", walletAddress)
    let version = await (await Wallet.at(walletAddress)).version();
    console.log("version", version)
    let latestVersion = await latestWallet.version();
    mlog.log ('latestVersion:', latestVersion);
    mlog.log ('version:', version);
    
    assert.ok (version != ZERO_BYTES8);    
    assert.equal (latestVersionAddress, latestWallet.address);
    assert.equal (version, latestVersion);
    
    const wallet2 = await Wallet2.new({from : owner2});
    const oracle2 = await Oracle2.new(owner1, owner2, owner3, {from: owner1});
    await oracle2.setPaymentAddress(owner2, {from: owner1});
    await oracle2.setPaymentAddress(owner2, {from: owner3});

    await instance.addVersion (wallet2.address, oracle2.address, { from: owner1 });
    //await instance.addVersion (wallet2.address, oracle2.address, { from: owner2 });
    await instance.deployVersion (await wallet2.version(), { from: owner1 });
    //await instance.deployVersion (await wallet2.version(), { from: owner2 });

    latestVersionAddress = await instance.getLatestVersion ({ from: owner1 });

    version = await (await Wallet.at(walletAddress)).version(); //should return Wallet2 version (not Wallet)
    latestVersion = await wallet2.version();

    mlog.log ('latestVersion:', latestVersion);
    mlog.log ('version:', version);

    assert.equal (latestVersionAddress, wallet2.address);
    assert.equal (version, latestVersion);
    
    latestWallet = wallet2;
  });

  it ('new user does not have a wallet without creating one', async () => {
    const walletAddress = await instance.getWallet.call (user2, { from: user2 });
    assert.equal (walletAddress, ZERO_ADDRESS);
  });

  it ('new user will get the latest version when creating a wallet in auto mode', async () => {
    let newaddress = await instance.createWallet (true, { from : user2, nonce: await web3.eth.getTransactionCount(user2) });
    console.log("Ori instance", instance.address)
    console.log("Ori newaddress", newaddress)
    const walletAddress = await instance.getWallet (user1, { from: user2 });
    const walletVersion = await (await Wallet.at(walletAddress)).version();
    const latestVersionAddress = await instance.getLatestVersion ({ from: owner1, nonce: await web3.eth.getTransactionCount(owner1) });
    const latestVersion = await latestWallet.version();
    assert.equal (walletVersion, latestVersion);
  });

  it ('restoreWalletConfiguration returns original owner and target when changed localy in case of version bug', async () => { 
    console.log("Ori instance.address", instance.address)
    //
    const walletAddress = await instance.getWallet(user2, { from: user2 });
    console.log("Ori walletAddress", walletAddress)
    const wallet = await Wallet2.at(walletAddress);

    let value = await wallet.getValue.call({ from :user2 });
    assert.equal (value.toString(10), 0);
      
    await wallet.setValue (2, 4, { from: user2, nonce: await web3.eth.getTransactionCount(user2) });
    value = await wallet.getValue.call({ from :user2 });
    assert.equal (value.toString(10), 8);

    await wallet.removeOwner ({ from: user2, nonce: await web3.eth.getTransactionCount(user2) });

    try {
      await wallet.setValue (2, 4, { from: user2, nonce: await web3.eth.getTransactionCount(user2) });
      assert(false);
    } catch (err) {
      assertRevert(err);
    }

    await wallet.removeTarget ({ from: user2, nonce: await web3.eth.getTransactionCount(user2) });

    try {
      value = await wallet.getValue.call ({ from: user2 });
      assert(false);
    } catch (err) {
    }
    // assert.equal (value.toString(10), 0);

    await instance.restoreWalletConfiguration({ from: user2, nonce: await web3.eth.getTransactionCount(user2) });

    value = await wallet.getValue.call({ from: user2 });
    assert.equal (value.toString(10), 8);

    await wallet.setValue (3, 5, { from: user2, nonce: await web3.eth.getTransactionCount(user2) });
    value = await wallet.getValue.call({ from :user2 });
    assert.equal (value.toString(10), 15);

  });

  it ('factory owner cannot call to addWalletBackup/removeWalletBackup/transferWalletOwnership', async () => {
    try {
      await instance.addWalletBackup (user3, { from: owner1, nonce: await web3.eth.getTransactionCount(owner1) });
      assert(false);
    } catch (err) {
      assertRevert(err);
    }
    try {
      await instance.removeWalletBackup (user3, { from: owner1, nonce: await web3.eth.getTransactionCount(owner1) });
      assert(false);
    } catch (err) {
      assertRevert(err);
    }

    try {
      await instance.transferWalletOwnership (user3, { from: owner1, nonce: await web3.eth.getTransactionCount(owner1) });
      assert(false);
    } catch (err) {
      assertRevert(err);
    }

  });

  it ('wallet owner cannot call directly to factory methods addWalletBackup/removeWalletBackup/transferWalletOwnership', async () => {      
    try {
      await instance.addWalletBackup (user3, { from: user1, nonce: await web3.eth.getTransactionCount(user1) });
      assert(false);
    } catch (err) {
      assertRevert(err);
    }
    try {
      await instance.removeWalletBackup (user3, { from: user1, nonce: await web3.eth.getTransactionCount(user1) });
      assert(false);
    } catch (err) {
      assertRevert(err);
    }

    try {
      await instance.transferWalletOwnership (user3, { from: user1, nonce: await web3.eth.getTransactionCount(user1) });
      assert(false);
    } catch (err) {
      assertRevert(err);
    }

  });

});
};
