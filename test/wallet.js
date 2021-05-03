'use strict';


// var ENS = artifacts.require("ens/ENS")
// const ENS = artifacts.require("ens/ENS");

// const ENSRegistry = artifacts.require('ens/ENSRegistry');
// const FIFSRegistrar = artifacts.require('ens/FIFSRegistrar');

const Wallet = artifacts.require("Wallet")
const Oracle = artifacts.require("Oracle")
const Factory = artifacts.require("Factory")
const FactoryProxy = artifacts.require("FactoryProxy")
const ERC20Token = artifacts.require("ERC20Token")
const ERC721Token = artifacts.require("ERC721Token")
const mlog = require('mocha-logger')
const { ZERO_ADDRESS, ZERO_BYTES32, ZERO_BN } = require('./lib/consts')

const io = require('socket.io-client')

const socket = io("ws://127.0.0.1:3003", {
  reconnectionDelayMax: 10000,
})

// console.log(JSON.stringify(ENS.address, null ,2))

const { ethers } = require('ethers')
const { TypedDataUtils } = require('ethers-eip712')

const { solidityPack, soliditySha256, solidityKeccak256, defaultAbiCoder, keccak256, toUtf8Bytes } = ethers.utils

const keys = require('./pkeys.json')

const {
  assertRevert,
  assertInvalidOpcode,
  assertPayable,
  assetEvent_getArgs
} = require('./lib/asserts');
contract('Wallet', async (accounts) => {
  let instance;
  let factory;
  let factoryProxy;
  let token20;
  let token20notSafe;
  let token721;
  let oracle;
  let DOMAIN_SEPARATOR;
  const factoryOwner1 = accounts[0];
  const factoryOwner2 = accounts[1];
  const factoryOwner3 = accounts[2];
  const owner         = accounts[3];
  const user1         = accounts[4];
  const user2         = accounts[5];
  const user3         = accounts[6];
  const operator      = accounts[7];
  const user4         = accounts[8];
  const activator     = accounts[9];
  const instances     = []
  
  const val1  = web3.utils.toWei('0.5', 'gwei');
  const val2  = web3.utils.toWei('0.4', 'gwei');
  const val3  = web3.utils.toWei('0.6', 'gwei');
  const valBN = web3.utils.toBN(val1).add(web3.utils.toBN(val2)).add(web3.utils.toBN(val3));

  const gas = 7000000
  const userCount = 2

  console.log('accounts', JSON.stringify(accounts))
  const getPrivateKey = (address) => {
    // const wallet = web3.currentProvider.wallets[address.toLowerCase()]
    if (address === owner) {
      return '0x5f055f3bc7f2c8cabcc5132d97d6b594c25becbc57139221f1ef89263efc99c7' // `0x${wallet._privKey.toString('hex')}`
    }
    if (address === operator) {
      return '0xf2eb3ee5aca80df482e9b6474f6af69b1186766ba10faf59a761aaa04ff405d0'
    }
  }

  const getSigner = (index) => {
    return ZERO_ADDRESS
    // return accounts[index]
  }

  const logBalances = async () => {
    mlog.log(`user1: ${await web3.eth.getBalance(accounts[10+userCount/2])}`)
    mlog.log(`user2: ${await web3.eth.getBalance(accounts[11+userCount/2])}`)
    mlog.log(`user3: ${await web3.eth.getBalance(accounts[12+userCount/2])}`)
    mlog.log(`user4: ${await web3.eth.getBalance(accounts[13+userCount/2])}`)
    mlog.log(`activator eth: ${await web3.eth.getBalance(activator)}`)
    mlog.log(`activator erc20: ${await token20.balanceOf(activator, { from: user1 })}`)
  }

  const logERC20Balances = async () => {
    mlog.log(`user1: ${await token20.balanceOf(accounts[10+userCount/2], { from: user1 })}`)
    mlog.log(`user2: ${await token20.balanceOf(accounts[11+userCount/2], { from: user1 })}`)
    mlog.log(`user3: ${await token20.balanceOf(accounts[12+userCount/2], { from: user1 })}`)
    mlog.log(`user4: ${await token20.balanceOf(accounts[13+userCount/2], { from: user1 })}`)
    mlog.log(`activator eth: ${await web3.eth.getBalance(activator)}`)
    mlog.log(`activator erc20: ${await token20.balanceOf(activator, { from: user1 })}`)
  }

  const logDebt = async () => {
    mlog.log(`user1 debt: ${await factory.getWalletDebt(accounts[10], { from: user1 })}`)
    mlog.log(`user2 debt: ${await factory.getWalletDebt(accounts[11], { from: user1 })}`)
    mlog.log(`user3 debt: ${await factory.getWalletDebt(accounts[12], { from: user1 })}`)
    mlog.log(`user4 debt: ${await factory.getWalletDebt(accounts[13], { from: user1 })}`)
    mlog.log(`activator debt: ${await factory.getWalletDebt(activator)}`)
  }
  
  const eip712sign = async (instance, typedData, account) => {
    mlog.log('typedData: ', JSON.stringify(typedData, null, 2))
    const domainHash = TypedDataUtils.hashStruct(typedData, 'EIP712Domain', typedData.domain)
    const domainHashHex = ethers.utils.hexlify(domainHash)
    mlog.log('CHAIN_ID', await instance.CHAIN_ID())
    mlog.log('DOMAIN_SEPARATOR', await instance.DOMAIN_SEPARATOR())
    mlog.log('DOMAIN_SEPARATOR (calculated)', domainHashHex)

    const messageDigest = TypedDataUtils.encodeDigest(typedData)
    const messageDigestHex = ethers.utils.hexlify(messageDigest)

    console.log('message:', messageDigestHex)
    // let signingKey = new ethers.utils.SigningKey(getPrivateKey(account));
    // const sig = signingKey.signDigest(messageDigest)
    // const rlp = ethers.utils.splitSignature(sig)
    // rlp.v = '0x' + rlp.v.toString(16)
  
    const signature = await new Promise(resolve => socket.emit('sign request', JSON.stringify([typedData]), resolve))
    const rlp = { r: signature.slice(0, 66), s: '0x'+signature.slice(66,130), v: '0x'+signature.slice(130) }

    const messageHash = TypedDataUtils.hashStruct(typedData, typedData.primaryType, typedData.message)
    const messageHashHex = ethers.utils.hexlify(messageHash)
    // mlog.log('messageHash (calculated)', messageHashHex)

    // const m = keccak256(toUtf8Bytes('batchCall(address activator,address to,uint256 value,uint256 nonce,bytes4 selector,address recipient,uint256 amount)'))
    // mlog.log('m (calculated)', m)

    const m2 = TypedDataUtils.typeHash(typedData.types, 'batchCall')
    const m2Hex = ethers.utils.hexZeroPad(ethers.utils.hexlify(m2), 32)
    console.log('m2 (calculated)', m2Hex)

    mlog.log('rlp', JSON.stringify(rlp))
    // mlog.log('recover', ethers.utils.recoverAddress(messageDigest, sig))
    return rlp
}

  const eip712typehash = (typedData, mainType) => {
    const m2 = TypedDataUtils.typeHash(typedData.types, typedData.primaryType)
    return ethers.utils.hexZeroPad(ethers.utils.hexlify(m2), 32)
}


  before('checking constants', async () => {
    assert(typeof factoryOwner1 == 'string', 'factoryOwner1 should be string');
    assert(typeof factoryOwner2 == 'string', 'factoryOwner2 should be string');
    assert(typeof factoryOwner3 == 'string', 'factoryOwner3 should be string');
    assert(typeof owner   == 'string', 'owner   should be string');
    assert(typeof user1   == 'string', 'user1   should be string');
    assert(typeof user2   == 'string', 'user2   should be string');
    assert(typeof user3   == 'string', 'user3   should be string');
    assert(typeof user4   == 'string', 'user4   should be string');
    assert(typeof val1    == 'string', 'val1    should be string');
    assert(typeof val2    == 'string', 'val2    should be string');
    assert(typeof val3    == 'string', 'val2    should be string');
    assert(valBN instanceof web3.utils.BN, 'valBN should be big number');
  });
  
  before('setup contract for the test', async () => {
    // for (const key of keys) {
    //   await web3.eth.accounts.wallet.add(key)
    // }
    // const ens = await ENS.deployed()

    const sw_factory = await Factory.new(factoryOwner1, factoryOwner2, factoryOwner3, { from: owner, nonce: await web3.eth.getTransactionCount(owner) })
    .on('receipt', function(receipt){ mlog.pending(`Creating Factory Cost ${receipt.gasUsed} gas`) })
    const sw_factory_proxy = await FactoryProxy.new(factoryOwner1, factoryOwner2, factoryOwner3, ZERO_ADDRESS, { from: owner })
    .on('receipt', function(receipt){ mlog.pending(`Creating Factory Proxy Cost ${receipt.gasUsed} gas`) })

    /// await ens.setAddress('user10.eth', accounts[10])
    // const sw_factory = await Factory.new(factoryOwner1, factoryOwner2, factoryOwner3, { from: owner, nonce: await web3.eth.getTransactionCount(owner) })
    // const sw_factory_proxy = await FactoryProxy.new(factoryOwner1, factoryOwner2, factoryOwner3, { from: owner })
    await sw_factory_proxy.setTarget(sw_factory.address, { from: factoryOwner1 });
    await sw_factory_proxy.setTarget(sw_factory.address, { from: factoryOwner2 });
    
    factory = await Factory.at(sw_factory_proxy.address, { from: factoryOwner3 });
    factoryProxy = await FactoryProxy.at(sw_factory_proxy.address, { from: factoryOwner3 });

    // const factory = await FactoryProxy.new({ from: creator });
    const version = await Wallet.new({ from: factoryOwner3 });
    oracle = await Oracle.new(factoryOwner1, factoryOwner2, factoryOwner3, {from: owner, nonce: await web3.eth.getTransactionCount(owner)});
    await oracle.setPaymentAddress(factoryOwner2, { from: factoryOwner2 });
    await oracle.setPaymentAddress(factoryOwner2, { from: factoryOwner1 });
    //await factory.addVersion(web3.fromAscii("1.1", 8), version.address, { from: creator });
    await factory.addVersion(version.address, oracle.address, { from: factoryOwner3 });
    await factory.addVersion(version.address, oracle.address, { from: factoryOwner1 });
    await factory.deployVersion(await version.version(), { from: factoryOwner1 });
    await factory.deployVersion(await version.version(), { from: factoryOwner2 });
    const { receipt } = await factory.createWallet(false, { from: owner });
    mlog.pending(`Creating Wallet Cost ${JSON.stringify(receipt.gasUsed)} gas`)
    instance = await Wallet.at( await factory.getWallet(owner));

    token20 = await ERC20Token.new('Kirobo ERC20 Token', 'KDB20', {from: owner});
    await oracle.update721(token20.address, true, {from: factoryOwner3});
    await oracle.cancel({from: factoryOwner2});
    await oracle.update20(token20.address, true, {from: factoryOwner1});
    await oracle.update20(token20.address, true, {from: factoryOwner3});
    token20notSafe = await ERC20Token.new('Kirobo ERC20 Not Safe Token', 'KDB20NS', {from: owner});
    token721 = await ERC721Token.new('Kirobo ERC721 Token', 'KBF', {from: owner});

    await factory.setOperator(operator, { from: factoryOwner1 });
    await factory.setOperator(operator, { from: factoryOwner2 });

    await factory.setActivator(activator, { from: factoryOwner1 });
    await factory.setActivator(activator, { from: factoryOwner2 });

    mlog.log('web3      ', web3.version);
    mlog.log('token20   ', token20.address);
    mlog.log('token20ns ', token20.address);
    mlog.log('token721  ', token20.address);
    mlog.log('factory   ', factory.address);
    mlog.log('wallet    ', instance.address);
    mlog.log('owner     ', owner);
    mlog.log('user1     ', user1);
    mlog.log('user2     ', user2);
    mlog.log('user3     ', user3);
    mlog.log('user4     ', user4);
    mlog.log('val1      ', val1);
    mlog.log('val2      ', val2);
    mlog.log('val3      ', val3);
    mlog.log('operator  ', operator);

    DOMAIN_SEPARATOR = (await instance.DOMAIN_SEPARATOR())
  });
  
  it('should create an empty wallet', async () => {
    const balance = await web3.eth.getBalance(instance.address);
    assert.equal(balance.toString(10), web3.utils.toBN('0').toString(10));
  });

  it('should accept ether from everyone', async () => {
    await web3.eth.sendTransaction({ gas, from: owner, value: val1, to: instance.address, nonce: await web3.eth.getTransactionCount(owner) });
    await web3.eth.sendTransaction({ gas, from: user1, value: val2, to: instance.address, nonce: await web3.eth.getTransactionCount(user1) });
    await web3.eth.sendTransaction({ gas, from: user2, value: val3, to: instance.address, nonce: await web3.eth.getTransactionCount(user2) });
    
    const balance = await web3.eth.getBalance(instance.address);
    assert.equal(balance.toString(10), valBN.toString(10));

    await token20.mint(user1, 10000, { from: owner, nonce: await web3.eth.getTransactionCount(owner) });
    await token20.mint(user2, 10000, { from: owner, nonce: await web3.eth.getTransactionCount(owner) });
    await token20.mint(user3, 10000, { from: owner, nonce: await web3.eth.getTransactionCount(owner) });
    await token20.mint(user4, 10000, { from: owner, nonce: await web3.eth.getTransactionCount(owner) });

    for (let i=10; i<10+userCount; ++i) {
      await token20.mint(accounts[i], 10000, { from: owner, nonce: await web3.eth.getTransactionCount(owner) });
    }
    for (let i=10; i<10+userCount/2; ++i) {
      const { receipt } = await factory.createWallet(false, { from: accounts[i] });
      mlog.pending(`Creating Wallet Cost ${JSON.stringify(receipt.gasUsed)} gas`)
      instances.push(await factory.getWallet(accounts[i]));
    }
    console.log('instances', instances)
    for (const instance of instances) {
      await token20.mint(instance, 10000, { from: owner, nonce: await web3.eth.getTransactionCount(owner) });
      await web3.eth.sendTransaction({ from: owner, value: val1, to: instance, nonce: await web3.eth.getTransactionCount(owner) });
    }

    await token20.transfer(instance.address, 5000, {from: user1, nonce: await web3.eth.getTransactionCount(user1)});
    const { receipt } = await token20.transfer(instance.address, 50, {from: user1, nonce: await web3.eth.getTransactionCount(user1)});
    mlog.pending(`ERC20 native Transfer consumed ${JSON.stringify(receipt.gasUsed)} gas`)
  });
  
  it('message: should be able to execute external calls', async () => {
    await instance.cancelCall({ from: owner })
    const data = token20.contract.methods.transfer(user1, 5).encodeABI()
    const nonce = await instance.nonce()
    const typeHash = '0x'.padEnd(66,'0')
    const msgData = defaultAbiCoder.encode(
        ['bytes32', 'address', 'address', 'uint256', 'uint256', 'bool', 'uint32', 'bytes4', 'bytes'],
        [typeHash, activator, token20.address, '0', nonce.toString(), false, 0, data.slice(0, 10), '0x' + data.slice(10)],
    )
    const rlp = await web3.eth.accounts.sign(web3.utils.sha3(msgData), getPrivateKey(owner))    
    const balance = await token20.balanceOf(user1, { from: user1 })
    const metaData = { simple: false, staticcall: false, gasLimit: 0 }
    const { receipt } = await instance.executeBatchCall([
      { v: rlp.v, r: rlp.r, s: rlp.s, typeHash, to: token20.address, value: 0, data, metaData}
      ]
      , { from: activator })
    const diff = (await token20.balanceOf(user1)).toNumber() - balance.toNumber()
    assert.equal (diff, 5, 'user1 balance change')
    mlog.pending(`ERC20 Transfer consumed ${JSON.stringify(receipt.gasUsed)} gas`)
  })


  // it('message: should be able to execute external calls', async () => {
  //   await instance.cancelCall({ from: owner })
  //   const data = token20.contract.methods.transfer(user1, 5).encodeABI()
  //   const nonce = await instance.nonce()
  //   const typeHash = '0x'.padEnd(66,'0')
  //   const msgData = defaultAbiCoder.encode(
  //       ['bytes32', 'address', 'address', 'uint256', 'uint256', 'bytes'],
  //       [typeHash, owner, token20.address, '0', nonce.toString(), data],
  //   )
  //   const rlp = await web3.eth.accounts.sign(web3.utils.sha3(msgData), getPrivateKey(operator))    
  //   const balance = await token20.balanceOf(user1, { from: user1 })
  //   const { receipt } = await instance.executeXCall(rlp.v, rlp.r, rlp.s, typeHash, token20.address, 0, data, { from: owner })
  //   const diff = (await token20.balanceOf(user1)).toNumber() - balance.toNumber()
  //   assert.equal (diff, 5, 'user1 balance change')
  //   mlog.pending(`ERC20 Transfer consumed ${JSON.stringify(receipt.gasUsed)} gas`)
  // })

  // it('message: should be able to execute external calls', async () => {
  //   await instance.cancelCall({ from: owner })
  //   const data = token20.contract.methods.transfer(user1, 5).encodeABI()
  //   const nonce = await instance.nonce()
  //   const typeHash = '0x'.padEnd(66,'0')
  //   const msgData = defaultAbiCoder.encode(
  //       ['bytes32', 'address', 'uint256', 'uint256', 'bytes'],
  //       [typeHash, token20.address, '0', nonce.toString(), data],
  //   )
  //   const rlp1 = await web3.eth.accounts.sign(web3.utils.sha3(msgData), getPrivateKey(owner))    
  //   const rlp2 = await web3.eth.accounts.sign(web3.utils.sha3(msgData), getPrivateKey(operator))    
  //   const balance = await token20.balanceOf(user1, { from: user1 })
  //   const { receipt } = await instance.executeXXCall(rlp1.v, rlp1.r, rlp1.s, rlp2.v, rlp2.r, rlp2.s, typeHash, token20.address, 0, data, { from: owner })
  //   const diff = (await token20.balanceOf(user1)).toNumber() - balance.toNumber()
  //   assert.equal (diff, 5, 'user1 balance change')
  //   mlog.pending(`ERC20 Transfer consumed ${JSON.stringify(receipt.gasUsed)} gas`)
  // })

  it('message: should be able to execute batch external calls', async () => {
    await instance.cancelCall({ from: owner })
    const data = token20.contract.methods.transfer(user1, 4).encodeABI()
    const data2 = token20.contract.methods.transfer(user2, 3).encodeABI()
    const data3 = token20.contract.methods.transfer(user3, 1).encodeABI()
    const data4 = token20.contract.methods.transfer(user4, 2).encodeABI()
    const nonce = await instance.nonce()
    const typeHash = '0x'.padEnd(66, '0')
    const msgData = defaultAbiCoder.encode(
      ['bytes32', 'address', 'address', 'uint256', 'uint256', 'bool', 'uint32', 'bytes4', 'bytes'],
      [typeHash, activator, token20.address, '0', nonce.toString(), false, 0, data.slice(0, 10), '0x' + data.slice(10)],
    )
    const msgData2 = defaultAbiCoder.encode(
      ['bytes32', 'address', 'address', 'uint256', 'uint256', 'bool', 'uint32', 'bytes4', 'bytes'],
      [typeHash, activator, token20.address, '0', +nonce.toString() + 1, false, 0, data2.slice(0, 10), '0x' + data2.slice(10)],
    )
    const msgData3 = defaultAbiCoder.encode(
      ['bytes32', 'address', 'address', 'uint256', 'uint256', 'bool', 'uint32', 'bytes4', 'bytes'],
      [typeHash, activator, token20.address, '0', +nonce.toString() + 2, false, 0, data3.slice(0, 10), '0x' + data3.slice(10)],
    )
    const msgData4 = defaultAbiCoder.encode(
      ['bytes32', 'address', 'address', 'uint256', 'uint256', 'bool', 'uint32', 'bytes4', 'bytes'],
      [typeHash, activator, token20.address, '0', +nonce.toString() + 3, false, 0, data4.slice(0, 10), '0x' + data4.slice(10)],
    )
    const rlp = await web3.eth.accounts.sign(web3.utils.sha3(msgData), getPrivateKey(owner))
    const rlp2 = await web3.eth.accounts.sign(web3.utils.sha3(msgData2), getPrivateKey(owner))
    const rlp3 = await web3.eth.accounts.sign(web3.utils.sha3(msgData3), getPrivateKey(owner))
    const rlp4 = await web3.eth.accounts.sign(web3.utils.sha3(msgData4), getPrivateKey(owner))
    const balance = await token20.balanceOf(user1, { from: user1 })
    const balance2 = await token20.balanceOf(user2, { from: user1 })
    const balance3 = await token20.balanceOf(user3, { from: user1 })
    const balance4 = await token20.balanceOf(user4, { from: user1 })
    const metaData = { simple: false, staticcall: false, gasLimit: 0 }
    const { receipt } = await instance.executeBatchCall(
      [
        { v: rlp.v,  r: rlp.r,  s: rlp.s,  typeHash, to: token20.address, value: 0, metaData, data },
        { v: rlp2.v, r: rlp2.r, s: rlp2.s, typeHash, to: token20.address, value: 0, metaData, data: data2 },
        { v: rlp3.v, r: rlp3.r, s: rlp3.s, typeHash, to: token20.address, value: 0, metaData, data: data3 },
        { v: rlp4.v, r: rlp4.r, s: rlp4.s, typeHash, to: token20.address, value: 0, metaData, data: data4 },
      ], { from: activator })
    const diff = (await token20.balanceOf(user1)).toNumber() - balance.toNumber()
    assert.equal (diff, 4, 'user1 balance change')
    const diff2 = (await token20.balanceOf(user2)).toNumber() - balance2.toNumber()
    assert.equal (diff2, 3, 'user2 balance change')
    const diff3 = (await token20.balanceOf(user3)).toNumber() - balance3.toNumber()
    assert.equal (diff3, 1, 'user2 balance change')
    const diff4 = (await token20.balanceOf(user4)).toNumber() - balance3.toNumber()
    assert.equal (diff4, 2, 'user2 balance change')
    mlog.pending(`ERC20 * 4 * Transfer consumed ${JSON.stringify(receipt.gasUsed)} gas (${Math.ceil(receipt.gasUsed/4)} gas per call)`)
  })

  it('message: should be able to execute batch of external calls: signer==owner, sender==activator', async () => {
    await instance.cancelCall({ from: owner })
    const data = token20.contract.methods.transfer(user1, 5).encodeABI()
    const nonce = await instance.nonce()
    const typeHash = '0x'.padEnd(66,'0')
    const msgData = defaultAbiCoder.encode(
        ['bytes32', 'address', 'address', 'uint256', 'uint256', 'bool', 'uint32', 'bytes4', 'bytes'],
        [typeHash, activator, token20.address, '0', nonce.toString(), false, 0, data.slice(0, 10), '0x' + data.slice(10)],
    )
    const rlp = await web3.eth.accounts.sign(web3.utils.sha3(msgData), getPrivateKey(owner))    
    const balance = await token20.balanceOf(user1, { from: user1 })
    const metaData = { simple: false, staticcall: false, gasLimit: 0 }
    const { receipt } = await instance.executeBatchCall([
      { v: rlp.v, r: rlp.r, s: rlp.s, typeHash, to: token20.address, value: 0, data, metaData }], { from: activator })
    const diff = (await token20.balanceOf(user1)).toNumber() - balance.toNumber()
    assert.equal (diff, 5, 'user1 balance change')
    mlog.pending(`ERC20 Transfer consumed ${JSON.stringify(receipt.gasUsed)} gas`)
  })

  it('message: should be able to execute batch of sends: signer==owner, sender==activator', async () => {
    await instance.cancelCall({ from: owner })
    const nonce = await instance.nonce()
    const typeHash = '0x'.padEnd(66,'0')
    const msgData = defaultAbiCoder.encode(
        ['bytes32', 'address', 'address', 'uint256', 'uint256', 'bool', 'uint32', 'bytes32'],
        [typeHash, activator, user3, '10', nonce.toString(), false, 0, keccak256(toUtf8Bytes(''))],
    )
    const rlp = await web3.eth.accounts.sign(web3.utils.sha3(msgData), getPrivateKey(owner))    
    const balance = await token20.balanceOf(user1, { from: user1 })
    const metaData = { simple: true, staticcall: false, gasLimit: 0 }
    const { receipt } = await instance.executeBatchCall([
      { v: rlp.v, r: rlp.r, s: rlp.s, typeHash, to: user3, value: 10, data: [], metaData }], { from: activator })
    const diff = (await token20.balanceOf(user1)).toNumber() - balance.toNumber()
    // assert.equal (diff, 5, 'user1 balance change')
    mlog.pending(`Eth Transfer consumed ${JSON.stringify(receipt.gasUsed)} gas`)
  })

  it('message: should be able to execute batch of sends and calls: signer==owner, sender==activator', async () => {
    await instance.cancelCall({ from: owner })
    const nonce = await instance.nonce()
    const typeHash = '0x'.padEnd(66,'0')
    const msgData = defaultAbiCoder.encode(
        ['bytes32', 'address', 'address', 'uint256', 'uint256', 'bool', 'uint32', 'bytes32'],
        [typeHash, activator, user3, '10', nonce.toString(), false, 0, keccak256(toUtf8Bytes(''))],
    )
    const rlp = await web3.eth.accounts.sign(web3.utils.sha3(msgData), getPrivateKey(owner))    

    const data2 = token20.contract.methods.transfer(user1, 5).encodeABI()
    const msgData2 = defaultAbiCoder.encode(
        ['bytes32', 'address', 'address', 'uint256', 'uint256', 'bool', 'uint32', 'bytes4', 'bytes'],
        [typeHash, activator, token20.address, '0', +nonce.toString()+1, false, 0, data2.slice(0, 10), '0x' + data2.slice(10)],
    )
    const rlp2 = await web3.eth.accounts.sign(web3.utils.sha3(msgData2), getPrivateKey(owner))    

    const msgData3 = defaultAbiCoder.encode(
        ['bytes32', 'address', 'address', 'uint256', 'uint256', 'bool', 'uint32', 'bytes32'],
        [typeHash, activator, user2, '8', +nonce.toString()+2, false, 0, keccak256('0x1234')],
    )
    const rlp3 = await web3.eth.accounts.sign(web3.utils.sha3(msgData3), getPrivateKey(owner))    

    const balance = await token20.balanceOf(user1, { from: user1 })
    const metaData = { simple: false, staticcall: false, gasLimit: 0 }
    const simpleMetaData = { simple: true, staticcall: false, gasLimit: 0 }
    const { receipt } = await instance.executeBatchCall([
      { v: rlp.v, r: rlp.r, s: rlp.s, typeHash, to: user3, value: 10, data: [], metaData: simpleMetaData },
      { v: rlp2.v, r: rlp2.r, s: rlp2.s, typeHash, to: token20.address, value: 0, data: data2, metaData },
      { v: rlp3.v, r: rlp3.r, s: rlp3.s, typeHash, to: user2, value: 8, data: '0x1234', metaData: simpleMetaData },
    ], { from: activator })
    const diff = (await token20.balanceOf(user1)).toNumber() - balance.toNumber()
    // assert.equal (diff, 5, 'user1 balance change')
    mlog.pending(`2 X Ether + ERC20 Transfers consumed ${JSON.stringify(receipt.gasUsed)} gas (${Math.ceil(receipt.gasUsed/3)} gas per call)`)
  })

  it('message: should be able to execute batch of external calls: signer==operator, sender==owner', async () => {
    await instance.cancelCall({ from: owner })
    const data = token20.contract.methods.transfer(user1, 5).encodeABI()
    const nonce = await instance.nonce()
    const typeHash = '0x'.padEnd(66,'0')
    const msgData = defaultAbiCoder.encode(
        ['bytes32', 'address', 'address', 'uint256', 'uint256', 'bool', 'uint32', 'bytes4', 'bytes'],
        [typeHash, owner, token20.address, '0', nonce.toString(), false, 0, data.slice(0, 10), '0x' + data.slice(10)],
    )
    const rlp = await web3.eth.accounts.sign(web3.utils.sha3(msgData), getPrivateKey(operator))    
    const balance = await token20.balanceOf(user1, { from: user1 })
    const { receipt } = await instance.executeBatchCall([
      {v: rlp.v, r: rlp.r, s: rlp.s, typeHash, to: token20.address, value: 0, data, metaData: { simple: false, staticcall: false, gasLimit: 0 }}], { from: owner })
    const diff = (await token20.balanceOf(user1)).toNumber() - balance.toNumber()
    assert.equal (diff, 5, 'user1 balance change')
    mlog.pending(`ERC20 Transfer consumed ${JSON.stringify(receipt.gasUsed)} gas`)
  })

  it('message: should be able to execute batch of external sends: signer==operator, sender==owner', async () => {
    await instance.cancelCall({ from: owner })
    const nonce = await instance.nonce()
    const typeHash = '0x'.padEnd(66,'0')
    const msgData = defaultAbiCoder.encode(
        ['bytes32', 'address', 'address', 'uint256', 'uint256', 'bool', 'uint32', 'bytes32'],
        [typeHash, owner, user2, '1', nonce.toString(), false, 0, keccak256(toUtf8Bytes(''))],
    )
    const rlp = await web3.eth.accounts.sign(web3.utils.sha3(msgData), getPrivateKey(operator))    
    const balance = await token20.balanceOf(user1, { from: user1 })
    const metaData = { simple: true, staticcall: false, gasLimit: 0 }
    const { receipt } = await instance.executeBatchCall([
      { v: rlp.v, r: rlp.r, s: rlp.s, typeHash, to: user2, value: 1, data: [], metaData }
    ], { from: owner })
    // const diff = (await token20.balanceOf(user1)).toNumber() - balance.toNumber()
    // assert.equal (diff, 5, 'user1 balance change')
    mlog.pending(`Ether Transfer consumed ${JSON.stringify(receipt.gasUsed)} gas`)
  })

  it('message: should be able to execute batch of many external sends: signer==operator, sender==owner', async () => {
    await instance.cancelCall({ from: owner })
    const nonce = await instance.nonce()
    const typeHash = keccak256(toUtf8Bytes('batchTransfer(address token_address,address recipient,uint256 token_amount,uint256 sessionId,uint40 after,uint40 before,uint32 gasLimit,uint64 gasPriceLimit)'))

    const sends = []

    for (let i=10+userCount/2; i<10+userCount; ++i) {
      sends.push({ to: accounts[i], value: 2 })
    }

    const group             = '000001'                   // 24 bit
    const tnonce            = '0000000001'               // 40 bit
    const after             = '0000000000'               // 40 bit
    const before            = 'ffffffffff'               // 40 bit
    const maxGas            = '00000000'                 // 32 bit
    const maxGasPrice       = '0000000ba43b7400'         // 64 bit
    const eip712            = 'f0' //payment             // 8  bit
    const sessionId         = `0x${group}${tnonce}${after}${before}${maxGas}${maxGasPrice}${eip712}`

    const groupERC20        = '000001'
    const tnonceERC20       = '0000000002'
    const afterERC20        = '0000000000'
    const beforeERC20       = 'ffffffffff'
    const maxGasERC20       = '00000000'
    const maxGasPriceERC20  = '0000000ba43b7400'
    const eip712ERC20       = 'f0' //payment
    const sessionIdERC20    = `0x${groupERC20}${tnonceERC20}${afterERC20}${beforeERC20}${maxGasERC20}${maxGasPriceERC20}${eip712ERC20}`

    const msgDataERC20 = sends.map((item, index) => ({
        ...item, 
        _hash: defaultAbiCoder.encode(
          ['bytes32', 'address', 'address', 'uint256', 'uint256', 'uint40', 'uint40', 'uint32', 'uint64'/*, 'bool', 'uint32', 'bytes32'*/],
          [typeHash, token20.address, item.to, item.value, sessionIdERC20, '0x'+afterERC20, '0x'+beforeERC20, '0x'+maxGasERC20, '0x'+maxGasPriceERC20 /*, +nonce.toString()+index,*/ /*false, 0, keccak256(toUtf8Bytes('')) */])
    }))

    const msgDataEth = sends.map((item, index) => ({
      ...item, 
      _hash: defaultAbiCoder.encode(
        ['bytes32', 'address', 'address', 'uint256', 'uint256', 'uint256', 'uint256', 'uint256', 'uint256'/*, 'bool', 'uint32', 'bytes32'*/],
        // ['bytes32', /*'address',*/ 'address', 'uint256', 'uint256', 'uint256'/*, 'bool', 'uint32', 'bytes32'*/],
        // [typeHash, /*ZERO_ADDRESS,*/ item.to, item.value, 10 + index, 200 /*, +nonce.toString()+index,*/ /*false, 0, keccak256(toUtf8Bytes('')) */])
        [typeHash, ZERO_ADDRESS, item.to, item.value, sessionId, '0x'+after, '0x'+before, '0x'+maxGas, '0x'+maxGasPrice /*, +nonce.toString()+index,*/ /*false, 0, keccak256(toUtf8Bytes('')) */])
  }))

    const metaData = { simple: true, staticcall: false, gasLimit: 0 }

    const msgsERC20 = (await Promise.all(msgDataERC20.map(async (item, index) => ({
      ...item,
      ...await web3.eth.accounts.sign(web3.utils.sha3(item._hash), keys[index+10] /*getPrivateKey(owner)*/),
      metaData,
      typeHash,
      data: [],
      signer: getSigner(index+10),
      sessionId: sessionIdERC20,
      // gasPriceLimit: 200,
      // eip712: 0,
      token: token20.address,
      _hash: undefined,
    })))).map(item=> ({...item, sessionId: item.sessionId + item.v.slice(2).padStart(2,'0') }))

    const msgsEth = (await Promise.all(msgDataEth.map(async (item, index) => ({
      ...item,
      ...await web3.eth.accounts.sign(web3.utils.sha3(item._hash), keys[index+10]), //getPrivateKey(owner)),
      metaData,
      typeHash,
      data: [],
      sessionId: sessionId,
      signer: getSigner(index+10),
      // gasPriceLimit: 200,
      // eip712: 0,
      token: ZERO_ADDRESS,
      _hash: undefined,
    })))).map(item=> ({...item, sessionId: item.sessionId + item.v.slice(2).padStart(2,'0') }))
    // .map(item => ({...item, vs: item._vs}))

    const balance = await token20.balanceOf(user1, { from: user1 })
    mlog.pending(`calling ${JSON.stringify(msgsERC20[0], null, 2)}`)

    // const { receipt } = await instance.unsecuredBatchCall(msgs, {...msgs[0]}, { from: owner, value: 1 })
    
    // Should revert
    // await factory.batchTransfer(msgs, { from: activator, gasPrice: 201 })

    // Should revert
    // await factory.batchTransfer(msgs, { from: owner, gasPrice: 200 })

    await logBalances()
    const { receipt: receiptEth } = await factoryProxy.batchTransfer(msgsEth, 1, { from: activator, gasPrice: 50e9 })
    // const { receipt: receiptEth } = await factoryProxy.batchEthTransfer(msgsEth, 0, false,{ from: activator, gasPrice: 200 })
    mlog.pending(`zxc Ether X ${msgsEth.length} Transfers consumed ${JSON.stringify(receiptEth.gasUsed)} gas (${JSON.stringify(receiptEth.gasUsed/msgsEth.length)} gas per call)`)
    await logBalances()
    await logDebt()

    await logERC20Balances()

    const { receipt: receiptERC20 } = await factoryProxy.batchTransfer(msgsERC20, 1, { from: activator, gasPrice: 50e9 })

    // Should revert
    // await factory.batchTransfer(msgs, { from: activator, gasPrice: 200 })

    // const diff = (await token20.balanceOf(user1)).toNumber() - balance.toNumber()
    // assert.equal (diff, 5, 'user1 balance change')
    mlog.pending(`zxc ERC20 X ${msgsERC20.length} Transfers consumed ${JSON.stringify(receiptERC20.gasUsed)} gas (${JSON.stringify(receiptERC20.gasUsed/msgsERC20.length)} gas per call)`)

    await logERC20Balances()
    await logDebt()

  })


it('message: should be able to execute batch of many external calls: signer==operator, sender==owner', async () => {
    await instance.cancelCall({ from: owner })
    const nonce = await instance.nonce()
    const typeHash = '0xf728cfc064674dacd2ced2a03acd588dfd299d5e4716726c6d5ec364d16406eb'; // 0x'.padEnd(66,'0')

    const sends = []

    for (let i=10+userCount/2; i<10+userCount; ++i) {
      sends.push({
        data: token20.contract.methods.transfer(accounts[i], 5).encodeABI(),
        value: 0,
        typeHash: '0x'.padEnd(66,'0'),
        to: token20.address
      })
    }

    const groupERC20        = '000002'
    const tnonceERC20       = '00000000'
    const afterERC20        = '0000000000'
    const beforeERC20       = 'ffffffffff'
    const maxGasERC20       = '00000000'
    const maxGasPriceERC20  = '00000000000000c8'
    const eip712ERC20       = 'f2' // ordered, payment

    const getSessionIdERC20 = index => (
      `0x${groupERC20}${tnonceERC20}${(index).toString(16).padStart(2,'0')}${afterERC20}${beforeERC20}${maxGasERC20}${maxGasPriceERC20}${eip712ERC20}`
    )

    const DOMAIN_SEPARATOR = (await factoryProxy.DOMAIN_SEPARATOR())

    const msgDataERC20 = sends.map((item, index) => ({
        ...item, 
        _hash: defaultAbiCoder.encode(
          ['bytes32', 'address', 'uint256', 'uint256', 'uint40', 'uint40', 'uint32', 'uint64', 'bytes4', 'bytes'],
          [item.typeHash, item.to, item.value, getSessionIdERC20(index), '0x'+afterERC20, '0x'+beforeERC20, '0x'+maxGasERC20, '0x'+maxGasPriceERC20, item.data.slice(0, 10), '0x' + item.data.slice(10)])
          // ['bytes32', 'address', 'uint256', 'uint256', 'uint40', 'uint40', 'uint32', 'uint64', 'string', 'bytes'],
          // [item.typeHash, item.to, item.value, getSessionIdERC20(index), '0x'+afterERC20, '0x'+beforeERC20, '0x'+maxGasERC20, '0x'+maxGasPriceERC20, 'transfer(address,uint256)', '0x' + item.data.slice(10)])
    }))

    // const metaData = { simple: true, staticcall: false, gasLimit: 0 }

    const msgsERC20 = (await Promise.all(msgDataERC20.map(async (item, index) => ({
      ...item,
      ...await web3.eth.accounts.sign(web3.utils.sha3(item._hash), keys[index+10] /*getPrivateKey(owner)*/),
      sessionId: getSessionIdERC20(index),
      selector: item.data.slice(0,10),
      functionInterface: 'transfer(address,uint256)',
      toEns: '',
      signer: getSigner(index+10),
      data: '0x' + item.data.slice(10),
      _hash: undefined,
    })))).map(item=> ({...item, sessionId: item.sessionId + item.v.slice(2).padStart(2,'0') }))

    const balance = await token20.balanceOf(user1, { from: user1 })
    mlog.pending(`calling ${JSON.stringify(msgsERC20[0], null, 2)}`)

    // const { receipt } = await instance.unsecuredBatchCall(msgs, {...msgs[0]}, { from: owner, value: 1 })
    
    // Should revert
    // await factory.batchTransfer(msgs, { from: activator, gasPrice: 201 })

    // Should revert
    // await factory.batchTransfer(msgs, { from: owner, gasPrice: 200 })

    await logERC20Balances()

    const { receipt: receiptERC20 } = await factoryProxy.batchCall(msgsERC20, 2, { from: activator, gasPrice: 200 })

    // Should revert
    // await factory.batchTransfer(msgs, { from: activator, gasPrice: 200 })

    // const diff = (await token20.balanceOf(user1)).toNumber() - balance.toNumber()
    // assert.equal (diff, 5, 'user1 balance change')
    mlog.pending(`================== ERC20 X ${msgsERC20.length} Transfers consumed ${JSON.stringify(receiptERC20.gasUsed)} gas (${JSON.stringify(receiptERC20.gasUsed/msgsERC20.length)} gas per call)`)

    await logERC20Balances()
    await logDebt()

  })

it('message: should be able to execute batch of many external static calls: signer==operator, sender==owner', async () => {
    await instance.cancelCall({ from: owner })
    const nonce = await instance.nonce()
    const typeHash = '0xf728cfc064674dacd2ced2a03acd588dfd299d5e4716726c6d5ec364d16406eb'; // 0x'.padEnd(66,'0')

    const sends = []

    for (let i=10+userCount/2; i<10+userCount; ++i) {
      sends.push({
        data: instance.contract.methods.erc20BalanceGT(token20.address, accounts[i], 10).encodeABI(),
        value: 0,
        typeHash: '0x'.padEnd(66,'0'),
        to: instance.address
      })
    }

    const groupERC20        = '000006'
    const tnonceERC20       = '00000000'
    const afterERC20        = '0000000000'
    const beforeERC20       = 'ffffffffff'
    const maxGasERC20       = '00000000'
    const maxGasPriceERC20  = '00000000000000c8'
    const eip712ERC20       = 'f6' // ordered + stataiccall + payment

    const getSessionIdERC20 = index => (
      `0x${groupERC20}${tnonceERC20}${(index).toString(16).padStart(2,'0')}${afterERC20}${beforeERC20}${maxGasERC20}${maxGasPriceERC20}${eip712ERC20}`
    )
    const DOMAIN_SEPARATOR = (await factoryProxy.DOMAIN_SEPARATOR())

    const msgDataERC20 = sends.map((item, index) => ({
        ...item, 
        _hash: defaultAbiCoder.encode(
          // ['bytes32', 'address', 'uint256', 'uint256', 'bytes4', 'bytes'],
          // [DOMAIN_SEPARATOR, item.to, item.value, getSessionIdERC20(index), item.data.slice(0, 10), '0x' + item.data.slice(10)])
          ['bytes32', 'address', 'uint256', 'uint256', 'uint40', 'uint40', 'uint32', 'uint64', 'bytes4', 'bytes'],
          [item.typeHash, item.to, item.value, getSessionIdERC20(index), '0x'+afterERC20, '0x'+beforeERC20, '0x'+maxGasERC20, '0x'+maxGasPriceERC20, item.data.slice(0, 10), '0x' + item.data.slice(10)])
    }))

    // const metaData = { simple: true, staticcall: false, gasLimit: 0 }

    const msgsERC20 = (await Promise.all(msgDataERC20.map(async (item, index) => ({
      ...item,
      ...await web3.eth.accounts.sign(web3.utils.sha3(item._hash), keys[index+10] /*getPrivateKey(owner)*/),
      sessionId: getSessionIdERC20(index),
      selector: item.data.slice(0,10),
      signer: getSigner(index+10),
      data: '0x' + item.data.slice(10),
      functionInterface: '',
      toEns: '',
      _hash: undefined,
    })))).map(item=> ({...item, sessionId: item.sessionId + item.v.slice(2).padStart(2,'0') }))

    const balance = await token20.balanceOf(user1, { from: user1 })
    mlog.pending(`calling ${JSON.stringify(msgsERC20[0], null, 2)}`)

    // const { receipt } = await instance.unsecuredBatchCall(msgs, {...msgs[0]}, { from: owner, value: 1 })
    
    // Should revert
    // await factory.batchTransfer(msgs, { from: activator, gasPrice: 201 })

    // Should revert
    // await factory.batchTransfer(msgs, { from: owner, gasPrice: 200 })

    await logERC20Balances()

    const { receipt: receiptERC20 } = await factoryProxy.batchCall(msgsERC20, 6, { from: activator, gasPrice: 200 })

    // Should revert
    // await factory.batchTransfer(msgs, { from: activator, gasPrice: 200 })

    // const diff = (await token20.balanceOf(user1)).toNumber() - balance.toNumber()
    // assert.equal (diff, 5, 'user1 balance change')
    mlog.pending(`ERC20 X ${msgsERC20.length} Transfers consumed ${JSON.stringify(receiptERC20.gasUsed)} gas (${JSON.stringify(receiptERC20.gasUsed/msgsERC20.length)} gas per call)`)

    await logERC20Balances()
    await logDebt()

  })

it('message: should be able to execute multi external calls: signer==operator, sender==owner', async () => {
    await instance.cancelCall({ from: owner })
    const nonce = await instance.nonce()

    const sends = []

    for (let i=10+userCount/2; i<10+userCount; ++i) {
      sends.push([
        // {
        //   data: instance.contract.methods.erc20BalanceGT(token20.address, accounts[i], 100000).encodeABI(),
        //   value: 0,
        //   typeHash: '0x'.padEnd(66,'1'),
        //   to: instance.address,
        //   staticcall: true,
        //   gasLimit: 0,
        //   flow: 0x12, // on_success_stop , on_fail_continue
        // },
        {
          data: token20.contract.methods.transfer(accounts[i], 5).encodeABI(),
          value: 0,
          typeHash: '0x'.padEnd(66,'1'),
          to: token20.address,
          gasLimit: 0,
          // flow: 0x10, // on_success_stop
        },
        // {
        //   data: token20.contract.methods.transfer(accounts[i+50], 5).encodeABI(),
        //   value: 0,
        //   typeHash: '0x'.padEnd(66,'1'),
        //   to: token20.address,
        //   gasLimit: 0,
        //   flow: 0, 
        // },
        // {
        //   data: token20.contract.methods.transfer(accounts[i+51], 5).encodeABI(),
        //   value: 0,
        //   typeHash: '0x'.padEnd(66,'1'),
        //   to: token20.address,
        //   gasLimit: 0,
        //   flow: 0,
        // },
        // {
        //   data: token20.contract.methods.transfer(accounts[i+52], 5).encodeABI(),
        //   value: 0,
        //   typeHash: '0x'.padEnd(66,'1'),
        //   to: token20.address,
        //   gasLimit: 0,
        //   flow: 0, 
        // },
        // {
        //   data: token20.contract.methods.transfer(accounts[i+53], 5).encodeABI(),
        //   value: 0,
        //   typeHash: '0x'.padEnd(66,'1'),
        //   to: token20.address,
        //   gasLimit: 0,
        //   flow: 0,
        // },
        // {
        //   data: instance.contract.methods.erc20BalanceGT(token20.address, accounts[i], 10000).encodeABI(),
        //   value: 0,
        //   typeHash: '0x'.padEnd(66,'1'),
        //   to: instance.address,
        //   staticcall: true,
        //   gasLimit: 0,
        // },
        // {
        //   data: token20.contract.methods.transfer(accounts[11+userCount/2], 3).encodeABI(),
        //   value: 0,
        //   typeHash: '0x'.padEnd(66,'1'),
        //   to: token20.address,
        //   gasLimit: 0,
        // },
      ])
    }

    // for (let i=10+userCount/2; i<10+userCount; ++i) {
    //   sends.push([
    //     {
    //       data: token20.contract.methods.transfer(accounts[12], 1).encodeABI(),
    //       value: 0,
    //       typeHash: '0x'.padEnd(66,'1'),
    //       to: token20.address
    //     },
    //     {
    //       data: token20.contract.methods.transfer(accounts[13], 2).encodeABI(),
    //       value: 0,
    //       typeHash: '0x'.padEnd(66,'1'),
    //       to: token20.address
    //     },
    //     {
    //       data: token20.contract.methods.transfer(accounts[14], 3).encodeABI(),
    //       value: 0,
    //       typeHash: '0x'.padEnd(66,'1'),
    //       to: token20.address
    //     },
    //     {
    //       data: token20.contract.methods.transfer(accounts[15], 4).encodeABI(),
    //       value: 0,
    //       typeHash: '0x'.padEnd(66,'1'),
    //       to: token20.address
    //     },
    //     {
    //       data: token20.contract.methods.transfer(accounts[16], 5).encodeABI(),
    //       value: 0,
    //       typeHash: '0x'.padEnd(66,'1'),
    //       to: token20.address
    //     },
    //     {
    //       data: token20.contract.methods.transfer(accounts[17], 1).encodeABI(),
    //       value: 0,
    //       typeHash: '0x'.padEnd(66,'1'),
    //       to: token20.address
    //     },
    //     {
    //       data: token20.contract.methods.transfer(accounts[18], 2).encodeABI(),
    //       value: 0,
    //       typeHash: '0x'.padEnd(66,'1'),
    //       to: token20.address
    //     },
    //     {
    //       data: token20.contract.methods.transfer(accounts[19], 3).encodeABI(),
    //       value: 0,
    //       typeHash: '0x'.padEnd(66,'1'),
    //       to: token20.address
    //     },
    //     {
    //       data: token20.contract.methods.transfer(accounts[20], 4).encodeABI(),
    //       value: 0,
    //       typeHash: '0x'.padEnd(66,'1'),
    //       to: token20.address
    //     },
    //     {
    //       data: token20.contract.methods.transfer(accounts[21], 5).encodeABI(),
    //       value: 0,
    //       typeHash: '0x'.padEnd(66,'1'),
    //       to: token20.address
    //     },
    //   ])
    // }

    const groupERC20        = '000004'
    const tnonceERC20       = '00000000'
    const afterERC20        = '0000000000'
    const beforeERC20       = 'ffffffffff'
    const maxGasERC20       = '00000000'
    const maxGasPriceERC20  = '00000000000000c8'
    const eip712ERC20       = 'f000' // not-ordered, payment
    const eip712ERC20Static = 'f400' // not-ordered, staticcall, payment

    const getSessionIdERC20 = (index, staticcall) => (
      `0x${groupERC20}${tnonceERC20}${(index).toString(16).padStart(2,'0')}${afterERC20}${beforeERC20}${maxGasERC20}${maxGasPriceERC20}${staticcall ? eip712ERC20 : eip712ERC20}`
    )

    // console.log('sends', JSON.stringify(sends, null,2))

    const msgDataERC20 = sends.map((send, index) => ({
        mcall: send.map(item => ({...item, flags: (item.flow ? item.flow : 0) + (item.stataiccall ? 4*256 : 0), selector: item.data.slice(0, 10), data: '0x' + item.data.slice(10)})), 
        _hash: defaultAbiCoder.encode(
          ['(bytes32,address,uint256,uint256,uint40,uint40,uint256,uint256,bytes4,bytes)[]'],
          [send.map(item => ([ 
                item.typeHash,
                item.to,
                item.value,
                getSessionIdERC20(index, item.staticcall),
                '0x'+afterERC20,
                '0x'+beforeERC20,
                '0x'+maxGasERC20,
                '0x'+maxGasPriceERC20,
                item.data.slice(0, 10),
                '0x' + item.data.slice(10),
              ]))
          ]
        )
          // ['bytes32','address','uint256','uint256','uint40','uint40','uint256','bytes4','bytes'],
          // [item.typeHash, item.to, item.value, getSessionIdERC20(index), '0x'+afterERC20, '0x'+beforeERC20, '0x'+maxGasPriceERC20, item.data.slice(0, 10), '0x' + item.data.slice(10)])
    }))


    // console.log('msgDataERC20:', JSON.stringify(msgDataERC20, null, 2))
    // const metaData = { simple: true, staticcall: false, gasLimit: 0 }

    const msgsERC20 = (await Promise.all(msgDataERC20.map(async (item, index) => ({
      ...item,
      ...await web3.eth.accounts.sign(web3.utils.sha3(item._hash), keys[index+10] /*getPrivateKey(owner)*/),
      sessionId: getSessionIdERC20(index),
      signer: getSigner(index+10),
      // _hash: undefined,
    })))) // .map(item=> ({...item, sessionId: item.sessionId + item.v.slice(2).padStart(2,'0') }))

    const balance = await token20.balanceOf(user1, { from: user1 })
    // mlog.pending(`calling ${JSON.stringify(msgsERC20, null, 2)}`)

    await logERC20Balances()

    const { receipt: receiptERC20 } = /*tx =*/ await factoryProxy.batchMultiCall(msgsERC20, 4, { from: activator, gasPrice: 200 }) // .catch(revertReason => console.log({ revertReason: JSON.stringify(revertReason, null ,2) }))

    mlog.pending(`ERC20 X ${msgsERC20.length} Transfers consumed ${JSON.stringify(receiptERC20.gasUsed)} gas (${JSON.stringify(receiptERC20.gasUsed/msgsERC20.length)} gas per call)`)

    await logERC20Balances()
    await logDebt()

  })


  it('message: should be able to execute batch of external calls: 2 signers, sender==owner', async () => {
    await instance.cancelCall({ from: owner })
    const data = token20.contract.methods.transfer(user1, 5).encodeABI()
    const nonce = await instance.nonce()
    const typeHash = '0x'.padEnd(66,'0')
    const msgData = defaultAbiCoder.encode(
        ['bytes32', 'address', 'uint256', 'uint256', 'bool', 'uint32', 'bytes4', 'bytes'],
        [typeHash, token20.address, '0', nonce.toString(), false, 0, data.slice(0, 10), '0x' + data.slice(10)],
    )
    const rlp1 = await web3.eth.accounts.sign(web3.utils.sha3(msgData), getPrivateKey(owner))    
    const rlp2 = await web3.eth.accounts.sign(web3.utils.sha3(msgData), getPrivateKey(operator))    
    const balance = await token20.balanceOf(user1, { from: user1 })
    const metaData = { simple: false, staticcall: false, gasLimit: 0 }
    const { receipt } = await instance.executeXXBatchCall([
      { v1: rlp1.v, r1: rlp1.r, s1: rlp1.s, v2: rlp2.v, r2: rlp2.r, s2: rlp2.s, typeHash, to: token20.address, value: 0, data, metaData }], { from: owner })
    const diff = (await token20.balanceOf(user1)).toNumber() - balance.toNumber()
    assert.equal (diff, 5, 'user1 balance change')
    mlog.pending(`ERC20 Transfer consumed ${JSON.stringify(receipt.gasUsed)} gas`)
  })

  it('eip712: should be able to execute external calls', async () => {
    const tokens = 2
    await instance.cancelCall({ from: owner })
    const data = token20.contract.methods.transfer(user1, 5).encodeABI()

    mlog.log('---> data', data)

    const typedData = {
      types: {
        EIP712Domain: [
          { name: "name",               type: "string" },
          { name: "version",            type: "string" },
          { name: "chainId",            type: "uint256" },
          { name: "verifyingContract",  type: "address" },
          { name: "salt",               type: "bytes32" }
        ],
        executeCall: [
          { name: 'activator',          type: 'address' },
          { name: 'contract',           type: 'address' },
          { name: 'eth',                type: 'uint256' },
          { name: 'nonce',              type: 'uint256' },
          { name: 'staticCall',         type: 'bool'    },
          { name: 'gasLimit',           type: 'uint32'  },
          { name: 'selector',           type: 'bytes4' },
          { name: 'trStart',            type: 'uint256' },
          { name: 'trLength',           type: 'uint256' },
          { name: 'recipient',          type: 'address' },
          { name: 'amount',             type: 'uint256' },
        ]
      },
      primaryType: 'executeCall',
      domain: {
        name: await instance.NAME(),
        version: await instance.VERSION(),
        chainId: '0x' + web3.utils.toBN(await instance.CHAIN_ID()).toString('hex'), // await web3.eth.getChainId(),
        verifyingContract: instance.address,
        salt: await instance.uid(),
      },
      message: {
        activator,
        contract: token20.address,
        eth: '0',
        nonce: (await instance.nonce()).toString(),
        staticCall: false,
        gasLimit: '0',
        selector: '0x' + data.slice(2,10),
        trStart: '288', // 9*32
        trLength: '64',
        recipient: user1,
        amount: '5',
      }
    }

    mlog.log('typedData: ', JSON.stringify(typedData, null, 2))
    const domainHash = TypedDataUtils.hashStruct(typedData, 'EIP712Domain', typedData.domain)
    const domainHashHex = ethers.utils.hexlify(domainHash)
    mlog.log('CHAIN_ID', await instance.CHAIN_ID())
    mlog.log('DOMAIN_SEPARATOR', await instance.DOMAIN_SEPARATOR())
    mlog.log('DOMAIN_SEPARATOR (calculated)', domainHashHex)

    const messageDigest = TypedDataUtils.encodeDigest(typedData)
    const messageDigestHex = ethers.utils.hexlify(messageDigest)
    let signingKey = new ethers.utils.SigningKey(getPrivateKey(owner));
    const sig = signingKey.signDigest(messageDigest)
    const rlp = ethers.utils.splitSignature(sig)
    rlp.v = '0x' + rlp.v.toString(16)
  
    const messageHash = TypedDataUtils.hashStruct(typedData, typedData.primaryType, typedData.message)
    const messageHashHex = ethers.utils.hexlify(messageHash)
    mlog.log('messageHash (calculated)', messageHashHex)

    const m = keccak256(toUtf8Bytes('executeCall(address activator,address to,uint256 value,uint256 nonce,bytes4 selector,address recipient,uint256 amount)'))
    mlog.log('m (calculated)', m)

    const m2 = TypedDataUtils.typeHash(typedData.types, 'executeCall')
    const m2Hex = ethers.utils.hexZeroPad(ethers.utils.hexlify(m2), 32)
    mlog.log('m2 (calculated)', m2Hex)

    mlog.log('rlp', JSON.stringify(rlp))
    mlog.log('recover', ethers.utils.recoverAddress(messageDigest, sig))

    const balance = await token20.balanceOf(user1, { from: user1 })

    const { receipt } = await instance.executeBatchCall([{ v: rlp.v, r: rlp.r, s: rlp.s, typeHash: m2Hex, to: token20.address, value: 0, metaData: { simple: false, staticcall: false, gasLimit: 0 }, data: data }], { from: activator })
    const diff = (await token20.balanceOf(user1)).toNumber() - balance.toNumber()
    assert.equal (diff, 5, 'user1 balance change')
    mlog.pending(`ERC20 Transfer consumed ${JSON.stringify(receipt.gasUsed)} gas`)
  })


  it('eip712: should be able to execute batch sends', async () => {
    const tokens = 2
    const data = token20.contract.methods.transfer(user1, 5).encodeABI()

    // batchTransfer(address token,address to,uint256 value,uint256 sessionId,uint40 after,uint40 before,uint32 gasLimit,uint64 gasPriceLimit)

    mlog.log('---> data', data)

    const groupERC20        = '000008'
    const tnonceERC20       = '0000000002'
    const afterERC20        = '0000000000'
    const beforeERC20       = 'ffffffffff'
    const maxGasERC20       = '00000000'
    const maxGasPriceERC20  = '0000000ba43b7400'
    const eip712ERC20       = 'f1' // payment + eip712
    const sessionIdERC20    = `0x${groupERC20}${tnonceERC20}${afterERC20}${beforeERC20}${maxGasERC20}${maxGasPriceERC20}${eip712ERC20}`

    const typedData = {
      types: {
        EIP712Domain: [
          { name: "name",               type: "string" },
          { name: "version",            type: "string" },
          { name: "chainId",            type: "uint256" },
          { name: "verifyingContract",  type: "address" },
          { name: "salt",               type: "bytes32" }
        ],
        batchTransfer: [
          { name: 'token_address',      type: 'address' },
          { name: 'recipient',          type: 'address' },
          { name: 'token_amount',       type: 'uint256' },
          { name: 'sessionId',          type: 'uint256' },
          { name: 'after',              type: 'uint40'  },
          { name: 'before',             type: 'uint40'  },
          { name: 'gasLimit',           type: 'uint32'  },
          { name: 'gasPriceLimit',      type: 'uint64'  },
        ]
      },
      primaryType: 'batchTransfer',
      domain: {
        name: await factoryProxy.NAME(),
        version: await factoryProxy.VERSION(),
        chainId: '0x' + web3.utils.toBN(await factoryProxy.CHAIN_ID()).toString('hex'), // await web3.eth.getChainId(),
        verifyingContract: factoryProxy.address,
        salt: await factoryProxy.uid(),
      },
      message: {
        ['KIROBO PROTECTS YOU']: '👍',
        token_address: token20.address,
        recipient: accounts[10+userCount/2],
        token_amount: '20',
        sessionId: sessionIdERC20,
        after: '0x' + afterERC20,
        before: '0x' + beforeERC20,
        gasLimit: '0x' + maxGasERC20,
        gasPriceLimit: '0x' + maxGasPriceERC20,
      }
    }

    mlog.log('typedData: ', JSON.stringify(typedData, null, 2))
    const domainHash = TypedDataUtils.hashStruct(typedData, 'EIP712Domain', typedData.domain)
    const domainHashHex = ethers.utils.hexlify(domainHash)
    mlog.log('CHAIN_ID', await factoryProxy.CHAIN_ID())
    mlog.log('DOMAIN_SEPARATOR', await factoryProxy.DOMAIN_SEPARATOR())
    mlog.log('DOMAIN_SEPARATOR (calculated)', domainHashHex)

    const messageDigest = TypedDataUtils.encodeDigest(typedData)
    const messageDigestHex = ethers.utils.hexlify(messageDigest)
    let signingKey = new ethers.utils.SigningKey(keys[10]);
    const sig = signingKey.signDigest(messageDigest)

    // const rlp = ethers.utils.splitSignature(sig)
    // rlp.v = '0x' + rlp.v.toString(16)

    const signature = await new Promise(resolve => socket.emit('sign request', JSON.stringify([typedData]), resolve))
    const rlp = { r: signature.slice(0, 66), s: '0x'+signature.slice(66,130), v: '0x'+signature.slice(130) }

    console.log('sig', rlp)
  
    const messageHash = TypedDataUtils.hashStruct(typedData, typedData.primaryType, typedData.message)
    const messageHashHex = ethers.utils.hexlify(messageHash)
    mlog.log('messageHash (calculated)', messageHashHex)

    const m = keccak256(toUtf8Bytes('batchTransfer(address token,address recipient,uint256 value,uint256 sessionId,uint40 after,uint40 before,uint32 gasLimit,uint64 gasPriceLimit)'))
    mlog.log('m (calculated)', m)

    const m2 = TypedDataUtils.typeHash(typedData.types, 'batchTransfer')
    const m2Hex = ethers.utils.hexZeroPad(ethers.utils.hexlify(m2), 32)
    mlog.log('m2 (calculated)', m2Hex)

    mlog.log('rlp', JSON.stringify(rlp))
    mlog.log('recover', ethers.utils.recoverAddress(messageDigest, sig))

    const balance = await token20.balanceOf(user1, { from: user1 })

    const msgsERC20 = [{
      ...typedData.message,
      sessionId: sessionIdERC20 + rlp.v.slice(2).padStart(2,'0'),
      signer: getSigner(10),
      r: rlp.r,
      s: rlp.s,
      to: typedData.message.recipient,
    }].map(item => ({...item, value:item.token_amount, token: item.token_address}))

    await logERC20Balances()

    const { receipt: receiptERC20 } = await factoryProxy.batchTransfer(msgsERC20, 8, { from: activator, gasPrice: 50e9 })

    mlog.pending(`ERC20 X ${msgsERC20.length} Transfers consumed ${JSON.stringify(receiptERC20.gasUsed)} gas (${JSON.stringify(receiptERC20.gasUsed/msgsERC20.length)} gas per call)`)

    await logERC20Balances()
    await logDebt()
    // const { receipt } = await instance.executeBatchCall([{ v: rlp.v, r: rlp.r, s: rlp.s, typeHash: m2Hex, to: token20.address, value: 0, metaData: { simple: false, staticcall: false, gasLimit: 0 }, data: data }], { from: activator })
    // const diff = (await token20.balanceOf(user1)).toNumber() - balance.toNumber()
    // assert.equal (diff, 5, 'user1 balance change')
    // mlog.pending(`ERC20 Transfer consumed ${JSON.stringify(receipt.gasUsed)} gas`)
  })


it('eip712: should be able to execute batch of many external calls: signer==operator, sender==owner', async () => {
    const sends = []
    
    for (let i=10; i<11; ++i) {
      sends.push({
        data: token20.contract.methods.transfer(accounts[11], 5).encodeABI(),
        value: 0,
        // typeHash: '0x'.padEnd(66,'0'),
        to: token20.address
      })
    }

    const groupERC20        = '000002'
    const tnonceERC20       = '00000010'
    const afterERC20        = '0000000000'
    const beforeERC20       = 'ffffffffff'
    const maxGasERC20       = '00000000'
    const maxGasPriceERC20  = '00000000000000c8'
    const eip712ERC20       = 'f3' // ordered, payment, eip712

    const getSessionIdERC20 = index => (
      `0x${groupERC20}${tnonceERC20}${(index).toString(16).padStart(2,'0')}${afterERC20}${beforeERC20}${maxGasERC20}${maxGasPriceERC20}${eip712ERC20}`
    )

    // const data = token20.contract.methods.transfer(accounts[10], 5).encodeABI()

    const typedData = {
      types: {
        EIP712Domain: [
          { name: "name",               type: "string" },
          { name: "version",            type: "string" },
          { name: "chainId",            type: "uint256" },
          { name: "verifyingContract",  type: "address" },
          { name: "salt",               type: "bytes32" }
        ],
        batchCall: [
          { name: 'token_address',   type: 'address' },
          // { name: 'token ens',           type: 'string' },
          { name: 'eth_value',           type: 'uint256' },
          // { name: 'sessionId',          type: 'uint256' },
          { name: 'group_id',           type: 'uint24'  },
          { name: 'nonce',              type: 'uint40'  },
          { name: 'signature_valid_from',          type: 'uint40'  },
          { name: 'signature_expires_at',          type: 'uint40'  },
          { name: 'gas_limit',           type: 'uint32'  },
          { name: 'gas_price_limit',      type: 'uint64'  },
          { name: 'view_only',          type: 'bool'    },
          { name: 'ordered',            type: 'bool'    },
          { name: 'refund',             type: 'bool'    },
//          { name: 'selector',           type: 'bytes4'  },
          { name: 'method_data_offset',         type: 'uint256' },
          { name: 'method_signature',   type: 'string'  },
          { name: 'method_data_legnth',         type: 'uint256' },
          { name: 'to',                 type: 'address' },
          { name: 'token_amount',        type: 'uint256' },
        ]
      },
      primaryType: 'batchCall',
      domain: {
        name: await factoryProxy.NAME(),
        version: await factoryProxy.VERSION(),
        chainId: '0x' + web3.utils.toBN(await factoryProxy.CHAIN_ID()).toString('hex'), // await web3.eth.getChainId(),
        verifyingContract: factoryProxy.address,
        salt: await factoryProxy.uid(),
      },
      message: {
        ['KIROBO PROTECTS YOU']: '👍',
        ['token_address']: token20.address,
        ['token_ens']: '@token.usdt.eth',
        eth_value: '0',
        // sessionId: getSessionIdERC20(10),

        [':-']: '',
        ['Transaction Limits']: '',
        [':--']: '',
        ['group_id']: Number.parseInt('0x' + groupERC20),
        nonce: Number.parseInt('0x' + tnonceERC20 + '00'),
        ordered: true,
        ['view_only']: false,
        refund: true,
        ['signature_valid_from']: Number.parseInt('0x' + afterERC20),
        ['signature_expires_at']: Number.parseInt('0x' + beforeERC20),
        ['gas_limit']: Number.parseInt('0x' + maxGasERC20),
        ['gas_price_limit']: Number.parseInt('0x' + maxGasPriceERC20),
  //      selector: '0x' + data.slice(2,10),
        [':---']: '',
        ['Contract\'s Method Header']: '',
        [':----']: '',
        ['method_signature']: 'transfer(address,uint256)',
        ['method_data_offset']: '0x1c0', // '480', // 13*32
        ['method_data_legnth']: '0x40',
        [':-----']: '',
        ['Contract\'s Method Data']: '',
        [':------']: '',
        ['to']: accounts[11],
        ['token_amount']: '5',
      }
    }

    const DOMAIN_SEPARATOR = (await factoryProxy.DOMAIN_SEPARATOR())

    const msgDataERC20 = sends.map((item, index) => ({
        ...item, 
        // _hash: defaultAbiCoder.encode(
        //   ['bytes32', 'address', 'uint256', 'uint256', 'uint40', 'uint40', 'uint32', 'uint64', 'bytes4', 'bytes'],
        //   [item.typeHash, item.to, item.value, getSessionIdERC20(0), '0x'+afterERC20, '0x'+beforeERC20, '0x'+maxGasERC20, '0x'+maxGasPriceERC20, item.data.slice(0, 10), '0x' + item.data.slice(10)])
        //   ['bytes32', 'address', 'uint256', 'uint256', 'uint40', 'uint40', 'uint32', 'uint64', 'bytes4', 'bytes'],
        //   [item.typeHash, item.to, item.value, getSessionIdERC20(0), '0x'+afterERC20, '0x'+beforeERC20, '0x'+maxGasERC20, '0x'+maxGasPriceERC20, item.data.slice(0, 10), '0x' + item.data.slice(10)])
          // ['bytes32', 'address', 'uint256', 'uint256', 'uint40', 'uint40', 'uint32', 'uint64', 'string', 'bytes'],
          // [item.typeHash, item.to, item.value, getSessionIdERC20(index), '0x'+afterERC20, '0x'+beforeERC20, '0x'+maxGasERC20, '0x'+maxGasPriceERC20, 'transfer(address,uint256)', '0x' + item.data.slice(10)])
    }))

    // const metaData = { simple: true, staticcall: false, gasLimit: 0 }

    const msgsERC20 = (await Promise.all(msgDataERC20.map(async (item, index) => ({
      ...item,
      // ...await web3.eth.accounts.sign(web3.utils.sha3(item._hash), keys[index+10] /*getPrivateKey(owner)*/),
      ...await eip712sign(factoryProxy, typedData, 10),
      typeHash: eip712typehash(typedData),
      sessionId: getSessionIdERC20(0),
      selector: item.data.slice(0,10),
      functionInterface: 'transfer(address,uint256)',
      toEns: '',
      value: '0',
      signer: getSigner(10),
      data: '0x' + item.data.slice(10),
      _hash: undefined,
    })))).map(item => ({...item, sessionId: item.sessionId + item.v.slice(2).padStart(2,'0') }))

    const balance = await token20.balanceOf(user1, { from: user1 })
    mlog.pending(`calling ${JSON.stringify(msgsERC20[0], null, 2)}`)

    // const { receipt } = await instance.unsecuredBatchCall(msgs, {...msgs[0]}, { from: owner, value: 1 })
    
    // Should revert
    // await factory.batchTransfer(msgs, { from: activator, gasPrice: 201 })

    // Should revert
    // await factory.batchTransfer(msgs, { from: owner, gasPrice: 200 })

    await logERC20Balances()

    const { receipt: receiptERC20 } = await factoryProxy.batchCall2(msgsERC20, 2, { from: activator, gasPrice: 200 })

    // Should revert
    // await factory.batchTransfer(msgs, { from: activator, gasPrice: 200 })

    // const diff = (await token20.balanceOf(user1)).toNumber() - balance.toNumber()
    // assert.equal (diff, 5, 'user1 balance change')
    mlog.pending(`================== ERC20 X ${msgsERC20.length} Transfers consumed ${JSON.stringify(receiptERC20.gasUsed)} gas (${JSON.stringify(receiptERC20.gasUsed/msgsERC20.length)} gas per call)`)

    await logERC20Balances()
    await logDebt()

  })

  // it('eip712: should be able to execute external calls', async () => {
  //   const tokens = 2
  //   const data = token20.contract.methods.transfer(user1, 5).encodeABI()

  //   mlog.log('---> data', data)

  //   const groupERC20        = '000002'
  //   const tnonceERC20       = '00000000'
  //   const afterERC20        = '0000000000'
  //   const beforeERC20       = 'ffffffffff'
  //   const maxGasERC20       = '00000000'
  //   const maxGasPriceERC20  = '00000000000000c8'
  //   const eip712ERC20       = 'f2' // ordered, payment

  //   const getSessionIdERC20 = index => (
  //     `0x${groupERC20}${tnonceERC20}${(index).toString(16).padStart(2,'0')}${afterERC20}${beforeERC20}${maxGasERC20}${maxGasPriceERC20}${eip712ERC20}`
  //   )

  //   const typedData = {
  //     types: {
  //       EIP712Domain: [
  //         { name: "name",               type: "string" },
  //         { name: "version",            type: "string" },
  //         { name: "chainId",            type: "uint256" },
  //         { name: "verifyingContract",  type: "address" },
  //         { name: "salt",               type: "bytes32" }
  //       ],
  //       batchCall: [
  //         { name: 'contract',           type: 'address' },
  //         { name: 'eth',                type: 'uint256' },
  //         { name: 'nonce',              type: 'uint256' },
  //         { name: 'staticCall',         type: 'bool'    },
  //         { name: 'gasLimit',           type: 'uint32'  },
  //         { name: 'selector',           type: 'bytes4' },
  //         { name: 'trStart',            type: 'uint256' },
  //         { name: 'trLength',           type: 'uint256' },
  //         { name: 'recipient',          type: 'address' },
  //         { name: 'amount',             type: 'uint256' },
  //       ]
  //     },
  //     primaryType: 'batchCall',
  //     domain: {
  //       name: await instance.NAME(),
  //       version: await instance.VERSION(),
  //       chainId: '0x' + web3.utils.toBN(await instance.CHAIN_ID()).toString('hex'), // await web3.eth.getChainId(),
  //       verifyingContract: instance.address,
  //       salt: await instance.uid(),
  //     },
  //     message: {
  //       activator,
  //       contract: token20.address,
  //       eth: '0',
  //       nonce: (await instance.nonce()).toString(),
  //       staticCall: false,
  //       gasLimit: '0',
  //       selector: '0x' + data.slice(2,10),
  //       trStart: '288', // 9*32
  //       trLength: '64',
  //       recipient: user1,
  //       amount: '5',
  //     }
  //   }

  //   mlog.log('typedData: ', JSON.stringify(typedData, null, 2))
  //   const domainHash = TypedDataUtils.hashStruct(typedData, 'EIP712Domain', typedData.domain)
  //   const domainHashHex = ethers.utils.hexlify(domainHash)
  //   mlog.log('CHAIN_ID', await instance.CHAIN_ID())
  //   mlog.log('DOMAIN_SEPARATOR', await instance.DOMAIN_SEPARATOR())
  //   mlog.log('DOMAIN_SEPARATOR (calculated)', domainHashHex)

  //   const messageDigest = TypedDataUtils.encodeDigest(typedData)
  //   const messageDigestHex = ethers.utils.hexlify(messageDigest)
  //   let signingKey = new ethers.utils.SigningKey(getPrivateKey(accounts[10]));
  //   const sig = signingKey.signDigest(messageDigest)
  //   const rlp = ethers.utils.splitSignature(sig)
  //   rlp.v = '0x' + rlp.v.toString(16)
  
  //   const messageHash = TypedDataUtils.hashStruct(typedData, typedData.primaryType, typedData.message)
  //   const messageHashHex = ethers.utils.hexlify(messageHash)
  //   mlog.log('messageHash (calculated)', messageHashHex)

  //   const m = keccak256(toUtf8Bytes('executeCall(address activator,address to,uint256 value,uint256 nonce,bytes4 selector,address recipient,uint256 amount)'))
  //   mlog.log('m (calculated)', m)

  //   const m2 = TypedDataUtils.typeHash(typedData.types, 'executeCall')
  //   const m2Hex = ethers.utils.hexZeroPad(ethers.utils.hexlify(m2), 32)
  //   mlog.log('m2 (calculated)', m2Hex)

  //   mlog.log('rlp', JSON.stringify(rlp))
  //   mlog.log('recover', ethers.utils.recoverAddress(messageDigest, sig))

  //   const balance = await token20.balanceOf(user1, { from: user1 })

  //   const { receipt } = await factoryProxy.batchCall([{ v: rlp.v, r: rlp.r, s: rlp.s, typeHash: m2Hex, to: token20.address, value: 0, metaData: { simple: false, staticcall: false, gasLimit: 0 }, data: data }], { from: activator })
  //   const diff = (await token20.balanceOf(user1)).toNumber() - balance.toNumber()
  //   assert.equal (diff, 5, 'user1 balance change')
  //   mlog.pending(`ERC20 Transfer consumed ${JSON.stringify(receipt.gasUsed)} gas`)
  // })


});
