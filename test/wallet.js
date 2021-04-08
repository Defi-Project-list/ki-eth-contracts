'use strict';

const Wallet = artifacts.require("Wallet");
const Oracle = artifacts.require("Oracle");
const Factory = artifacts.require("Factory");
const FactoryProxy = artifacts.require("FactoryProxy");
const ERC20Token = artifacts.require("ERC20Token");
const ERC721Token = artifacts.require("ERC721Token");
const mlog = require('mocha-logger');

const { ethers } = require('ethers')

const { solidityPack, soliditySha256, solidityKeccak256, defaultAbiCoder, keccak256, toUtf8Bytes } = ethers.utils

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
  let DOMAIN_SEPARATOR;
  const factoryOwner1 = accounts[0];
  const factoryOwner2 = accounts[1];
  const factoryOwner3 = accounts[2];
  const owner         = accounts[3];
  const user1         = accounts[4];
  const user2         = accounts[5];
  const user3         = accounts[6];
  const activator     = accounts[7];
  const user4         = accounts[8];
  
  const val1  = web3.utils.toWei('0.5', 'gwei');
  const val2  = web3.utils.toWei('0.4', 'gwei');
  const val3  = web3.utils.toWei('0.6', 'gwei');
  const valBN = web3.utils.toBN(val1).add(web3.utils.toBN(val2)).add(web3.utils.toBN(val3));

  const getPrivateKey = (address) => {
    // const wallet = web3.currentProvider.wallets[address.toLowerCase()]
    if (address === owner) {
      return '0x5f055f3bc7f2c8cabcc5132d97d6b594c25becbc57139221f1ef89263efc99c7' // `0x${wallet._privKey.toString('hex')}`
    }
    if (address === activator) {
      return '0xf2eb3ee5aca80df482e9b6474f6af69b1186766ba10faf59a761aaa04ff405d0'
    }
  }

  before('checking constants', async () => {
    assert(typeof factoryOwner1 == 'string', 'factoryOwner1 should be string');
    assert(typeof factoryOwner2 == 'string', 'factoryOwner2 should be string');
    assert(typeof factoryOwner3 == 'string', 'factoryOwner3 should be string');
    assert(typeof owner   == 'string', 'owner   should be string');
    assert(typeof user1   == 'string', 'user1   should be string');
    assert(typeof user2   == 'string', 'user2   should be string');
    assert(typeof user3   == 'string', 'user3   should be string');
    assert(typeof val1    == 'string', 'val1    should be string');
    assert(typeof val2    == 'string', 'val2    should be string');
    assert(typeof val3    == 'string', 'val2    should be string');
    assert(valBN instanceof web3.utils.BN, 'valBN should be big number');
  });
  
  before('setup contract for the test', async () => {
    const sw_factory = await Factory.new(factoryOwner1, factoryOwner2, factoryOwner3, { from: owner, nonce: await web3.eth.getTransactionCount(owner) });
    const sw_factory_proxy = await FactoryProxy.new(factoryOwner1, factoryOwner2, factoryOwner3, { from: owner });
    await sw_factory_proxy.setTarget(sw_factory.address, { from: factoryOwner1 });
    await sw_factory_proxy.setTarget(sw_factory.address, { from: factoryOwner2 });
    factory = await Factory.at(sw_factory_proxy.address, { from: factoryOwner3 });
    
    //const factory = await FactoryProxy.new({ from: creator });
    const version = await Wallet.new({ from: factoryOwner3 });
    oracle = await Oracle.new(factoryOwner1, factoryOwner2, factoryOwner3, {from: owner, nonce: await web3.eth.getTransactionCount(owner)});
    await oracle.setPaymentAddress(factoryOwner2, { from: factoryOwner2 });
    await oracle.setPaymentAddress(factoryOwner2, { from: factoryOwner1 });
    //await factory.addVersion(web3.fromAscii("1.1", 8), version.address, { from: creator });
    await factory.addVersion(version.address, oracle.address, { from: factoryOwner3 });
    await factory.addVersion(version.address, oracle.address, { from: factoryOwner1 });
    await factory.deployVersion(await version.version(), { from: factoryOwner1 });
    await factory.deployVersion(await version.version(), { from: factoryOwner2 });
    await factory.createWallet(false, { from: owner });
    instance = await Wallet.at( await factory.getWallet(owner) );

    token20 = await ERC20Token.new('Kirobo ERC20 Token', 'KDB20', {from: owner});
    await oracle.update721(token20.address, true, {from: factoryOwner3});
    await oracle.cancel({from: factoryOwner2});
    await oracle.update20(token20.address, true, {from: factoryOwner1});
    await oracle.update20(token20.address, true, {from: factoryOwner3});
    token20notSafe = await ERC20Token.new('Kirobo ERC20 Not Safe Token', 'KDB20NS', {from: owner});
    token721 = await ERC721Token.new('Kirobo ERC721 Token', 'KBF', {from: owner});

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
    mlog.log('val1      ', val1);
    mlog.log('val2      ', val2);
    mlog.log('val3      ', val3);
    mlog.log('activator ', activator);

    DOMAIN_SEPARATOR = (await instance.DOMAIN_SEPARATOR())
  });
  
  it('should create empty wallet', async () => {
    const balance = await web3.eth.getBalance(instance.address);
    assert.equal(balance.toString(10), web3.utils.toBN('0').toString(10));
  });

  it('should accept ether from everyone', async () => {
    await web3.eth.sendTransaction({ from: owner, value: val1, to: instance.address, nonce: await web3.eth.getTransactionCount(owner) });
    await web3.eth.sendTransaction({ from: user1, value: val2, to: instance.address, nonce: await web3.eth.getTransactionCount(user1) });
    await web3.eth.sendTransaction({ from: user2, value: val3, to: instance.address, nonce: await web3.eth.getTransactionCount(user2) });
    
    const balance = await web3.eth.getBalance(instance.address);
    assert.equal(balance.toString(10), valBN.toString(10));

    await token20.mint(user1, 1000, { from: owner, nonce: await web3.eth.getTransactionCount(owner) });
    await token20.mint(user2, 1000, { from: owner, nonce: await web3.eth.getTransactionCount(owner) });
    await token20.mint(user3, 1000, { from: owner, nonce: await web3.eth.getTransactionCount(owner) });
    await token20.mint(user4, 1000, { from: owner, nonce: await web3.eth.getTransactionCount(owner) });
    await token20.transfer(instance.address, 50, {from: user1, nonce: await web3.eth.getTransactionCount(user1)});
    const { receipt } = await token20.transfer(instance.address, 50, {from: user1, nonce: await web3.eth.getTransactionCount(user1)});
    mlog.pending(`ERC20 native Transfer consumed ${JSON.stringify(receipt.gasUsed)} gas`)
  });
  
  it('message: should be able to execute external calls', async () => {
    await instance.cacnelCall({ from: owner })
    const data = token20.contract.methods.transfer(user1, 5).encodeABI()
    const nonce = await instance.nonce()
    const typeHash = '0x'.padEnd(66,'0')
    const msgData = defaultAbiCoder.encode(
        ['bytes32', 'address', 'address', 'uint256', 'uint256', 'bytes'],
        [typeHash, activator, token20.address, '0', nonce.toString(), data],
    )
    const rlp = await web3.eth.accounts.sign(web3.utils.sha3(msgData), getPrivateKey(owner))    
    const balance = await token20.balanceOf(user1, { from: user1 })
    const { receipt } = await instance.executeCall(rlp.v, rlp.r, rlp.s, typeHash, token20.address, 0, data, { from: activator })
    const diff = (await token20.balanceOf(user1)).toNumber() - balance.toNumber()
    assert.equal (diff, 5, 'user1 balance change')
    mlog.pending(`ERC20 Transfer consumed ${JSON.stringify(receipt.gasUsed)} gas`)
  })

  it('message: should be able to execute external calls', async () => {
    await instance.cacnelCall({ from: owner })
    const data = token20.contract.methods.transfer(user1, 5).encodeABI()
    const nonce = await instance.nonce()
    const typeHash = '0x'.padEnd(66,'0')
    const msgData = defaultAbiCoder.encode(
        ['bytes32', 'address', 'address', 'uint256', 'uint256', 'bytes'],
        [typeHash, owner, token20.address, '0', nonce.toString(), data],
    )
    const rlp = await web3.eth.accounts.sign(web3.utils.sha3(msgData), getPrivateKey(activator))    
    const balance = await token20.balanceOf(user1, { from: user1 })
    const { receipt } = await instance.executeXCall(rlp.v, rlp.r, rlp.s, typeHash, token20.address, 0, data, { from: owner })
    const diff = (await token20.balanceOf(user1)).toNumber() - balance.toNumber()
    assert.equal (diff, 5, 'user1 balance change')
    mlog.pending(`ERC20 Transfer consumed ${JSON.stringify(receipt.gasUsed)} gas`)
  })

  it('message: should be able to execute external calls', async () => {
    await instance.cacnelCall({ from: owner })
    const data = token20.contract.methods.transfer(user1, 5).encodeABI()
    const nonce = await instance.nonce()
    const typeHash = '0x'.padEnd(66,'0')
    const msgData = defaultAbiCoder.encode(
        ['bytes32', 'address', 'uint256', 'uint256', 'bytes'],
        [typeHash, token20.address, '0', nonce.toString(), data],
    )
    const rlp1 = await web3.eth.accounts.sign(web3.utils.sha3(msgData), getPrivateKey(owner))    
    const rlp2 = await web3.eth.accounts.sign(web3.utils.sha3(msgData), getPrivateKey(activator))    
    const balance = await token20.balanceOf(user1, { from: user1 })
    const { receipt } = await instance.executeXXCall(rlp1.v, rlp1.r, rlp1.s, rlp2.v, rlp2.r, rlp2.s, typeHash, token20.address, 0, data, { from: owner })
    const diff = (await token20.balanceOf(user1)).toNumber() - balance.toNumber()
    assert.equal (diff, 5, 'user1 balance change')
    mlog.pending(`ERC20 Transfer consumed ${JSON.stringify(receipt.gasUsed)} gas`)
  })

  it('message: should be able to execute batch external calls', async () => {
    await instance.cacnelCall({ from: owner })
    const data = token20.contract.methods.transfer(user1, 4).encodeABI()
    const data2 = token20.contract.methods.transfer(user2, 3).encodeABI()
    const data3 = token20.contract.methods.transfer(user3, 1).encodeABI()
    const data4 = token20.contract.methods.transfer(user4, 2).encodeABI()
    const nonce = await instance.nonce()
    const typeHash = '0x'.padEnd(66,'0')
    const msgData = defaultAbiCoder.encode(
        ['bytes32', 'address', 'address', 'uint256', 'uint256', 'bytes'],
        [typeHash, activator, token20.address, '0', nonce.toString(), data],
    )
    const msgData2 = defaultAbiCoder.encode(
        ['bytes32', 'address', 'address', 'uint256', 'uint256', 'bytes'],
        [typeHash, activator, token20.address, '0', +nonce.toString()+1, data2],
    )
    const msgData3 = defaultAbiCoder.encode(
        ['bytes32', 'address', 'address', 'uint256', 'uint256', 'bytes'],
        [typeHash, activator, token20.address, '0', +nonce.toString()+2, data3],
    )
    const msgData4 = defaultAbiCoder.encode(
        ['bytes32', 'address', 'address', 'uint256', 'uint256', 'bytes'],
        [typeHash, activator, token20.address, '0', +nonce.toString()+3, data4],
    )
    const rlp = await web3.eth.accounts.sign(web3.utils.sha3(msgData), getPrivateKey(owner))    
    const rlp2 = await web3.eth.accounts.sign(web3.utils.sha3(msgData2), getPrivateKey(owner))    
    const rlp3 = await web3.eth.accounts.sign(web3.utils.sha3(msgData3), getPrivateKey(owner))    
    const rlp4 = await web3.eth.accounts.sign(web3.utils.sha3(msgData4), getPrivateKey(owner))    
    const balance = await token20.balanceOf(user1, { from: user1 })
    const balance2 = await token20.balanceOf(user2, { from: user1 })
    const balance3 = await token20.balanceOf(user3, { from: user1 })
    const balance4 = await token20.balanceOf(user4, { from: user1 })
    const { receipt } = await instance.executeBatchCall(
      [
        {v:rlp.v, r:rlp.r, s:rlp.s, typeHash, to: token20.address, value: 0, data},
        {v:rlp2.v, r:rlp2.r, s:rlp2.s, typeHash, to: token20.address, value: 0, data: data2},
        {v:rlp3.v, r:rlp3.r, s:rlp3.s, typeHash, to: token20.address, value: 0, data: data3},
        {v:rlp4.v, r:rlp4.r, s:rlp4.s, typeHash, to: token20.address, value: 0, data: data4}
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

  it('message: should be able to execute batch of external calls', async () => {
    await instance.cacnelCall({ from: owner })
    const data = token20.contract.methods.transfer(user1, 5).encodeABI()
    const nonce = await instance.nonce()
    const typeHash = '0x'.padEnd(66,'0')
    const msgData = defaultAbiCoder.encode(
        ['bytes32', 'address', 'address', 'uint256', 'uint256', 'bytes'],
        [typeHash, activator, token20.address, '0', nonce.toString(), data],
    )
    const rlp = await web3.eth.accounts.sign(web3.utils.sha3(msgData), getPrivateKey(owner))    
    const balance = await token20.balanceOf(user1, { from: user1 })
    const { receipt } = await instance.executeBatchCall([{v: rlp.v, r: rlp.r, s: rlp.s, typeHash, to: token20.address, value: 0, data}], { from: activator })
    const diff = (await token20.balanceOf(user1)).toNumber() - balance.toNumber()
    assert.equal (diff, 5, 'user1 balance change')
    mlog.pending(`ERC20 Transfer consumed ${JSON.stringify(receipt.gasUsed)} gas`)
  })

  it('message: should be able to execute batch of external calls', async () => {
    await instance.cacnelCall({ from: owner })
    const data = token20.contract.methods.transfer(user1, 5).encodeABI()
    const nonce = await instance.nonce()
    const typeHash = '0x'.padEnd(66,'0')
    const msgData = defaultAbiCoder.encode(
        ['bytes32', 'address', 'address', 'uint256', 'uint256', 'bytes'],
        [typeHash, owner, token20.address, '0', nonce.toString(), data],
    )
    const rlp = await web3.eth.accounts.sign(web3.utils.sha3(msgData), getPrivateKey(activator))    
    const balance = await token20.balanceOf(user1, { from: user1 })
    const { receipt } = await instance.executeXBatchCall([{v: rlp.v, r: rlp.r, s: rlp.s, typeHash, to: token20.address, value: 0, data}], { from: owner })
    const diff = (await token20.balanceOf(user1)).toNumber() - balance.toNumber()
    assert.equal (diff, 5, 'user1 balance change')
    mlog.pending(`ERC20 Transfer consumed ${JSON.stringify(receipt.gasUsed)} gas`)
  })

  it('message: should be able to execute batch of external calls', async () => {
    await instance.cacnelCall({ from: owner })
    const data = token20.contract.methods.transfer(user1, 5).encodeABI()
    const nonce = await instance.nonce()
    const typeHash = '0x'.padEnd(66,'0')
    const msgData = defaultAbiCoder.encode(
        ['bytes32', 'address', 'uint256', 'uint256', 'bytes'],
        [typeHash, token20.address, '0', nonce.toString(), data],
    )
    const rlp1 = await web3.eth.accounts.sign(web3.utils.sha3(msgData), getPrivateKey(owner))    
    const rlp2 = await web3.eth.accounts.sign(web3.utils.sha3(msgData), getPrivateKey(activator))    
    const balance = await token20.balanceOf(user1, { from: user1 })
    const { receipt } = await instance.executeXXBatchCall([{v1: rlp1.v, r1: rlp1.r, s1: rlp1.s, v2: rlp2.v, r2: rlp2.r, s2: rlp2.s, typeHash, to: token20.address, value: 0, data}], { from: owner })
    const diff = (await token20.balanceOf(user1)).toNumber() - balance.toNumber()
    assert.equal (diff, 5, 'user1 balance change')
    mlog.pending(`ERC20 Transfer consumed ${JSON.stringify(receipt.gasUsed)} gas`)
  })

  it('eip712: should be able to execute external calls', async () => {
  //   const tokens = 500
  //   const secret = 'my secret2'
  //   const secretHash = web3.utils.sha3(secret)
  //   await pool.issueTokens(user1, tokens, secretHash, { from: poolOwner })
  //   const message = await pool.generateAcceptTokensMessage(user1, tokens, secretHash, { from: poolOwner })
  //   mlog.log('message: ', message)
  //   const typedData = {
  //     types: {
  //       EIP712Domain: [
  //         { name: "name",               type: "string" },
  //         { name: "version",            type: "string" },
  //         { name: "chainId",            type: "uint256" },
  //         { name: "verifyingContract",  type: "address" },
  //         { name: "salt",               type: "bytes32" }
  //       ],
  //       acceptTokens: [
  //         { name: 'recipient',          type: 'address' },
  //         { name: 'value',              type: 'uint256' },
  //         { name: 'secretHash',         type: 'bytes32' },
  //       ]
  //     },
  //     primaryType: 'acceptTokens',
  //     domain: {
  //       name: await pool.NAME(),
  //       version: await pool.VERSION(),
  //       chainId: '0x' + web3.utils.toBN(await pool.CHAIN_ID()).toString('hex'), // await web3.eth.getChainId(),
  //       verifyingContract: pool.address,
  //       salt: await pool.uid(),
  //     },
  //     message: {
  //       recipient: user1,
  //       value: '0x' + web3.utils.toBN(tokens).toString('hex'),
  //       secretHash,
  //     }
  //   }
  //   mlog.log('typedData: ', JSON.stringify(typedData, null, 2))
  //   const domainHash = TypedDataUtils.hashStruct(typedData, 'EIP712Domain', typedData.domain)
  //   const domainHashHex = ethers.utils.hexlify(domainHash)
  //   mlog.log('CHAIN_ID', await pool.CHAIN_ID())
  //   mlog.log('DOMAIN_SEPARATOR', await pool.DOMAIN_SEPARATOR())
  //   mlog.log('DOMAIN_SEPARATOR (calculated)', domainHashHex)
    
  //   const { defaultAbiCoder, keccak256, toUtf8Bytes } = ethers.utils

  //   mlog.log('DOMAIN_SEPARATOR (calculated2)', keccak256(defaultAbiCoder.encode(
  //       ['bytes32', 'bytes32', 'bytes32', 'uint256', 'address', 'bytes32'],
  //       [
  //         keccak256(
  //           toUtf8Bytes('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract,bytes32 salt)')
  //         ),
  //         keccak256(toUtf8Bytes(await pool.NAME())),
  //         keccak256(toUtf8Bytes(await pool.VERSION())),
  //         '0x' + web3.utils.toBN(await pool.CHAIN_ID()).toString('hex'),
  //         pool.address,
  //         await pool.uid(),
  //       ]
  //   )))

  //   const messageDigest = TypedDataUtils.encodeDigest(typedData)
  //   const messageDigestHex = ethers.utils.hexlify(messageDigest)
  //   let signingKey = new ethers.utils.SigningKey(getPrivateKey(user1));
  //   const sig = signingKey.signDigest(messageDigest)
  //   const rlp = ethers.utils.splitSignature(sig)
  //   rlp.v = '0x' + rlp.v.toString(16)
  //   // const messageDigestHash = messageDigestHex.slice(2)
  //   // mlog.log('messageDigestHash', messageDigestHash)
  //   mlog.log('user1', user1, 'tokens', tokens, 'secretHash', secretHash)
  //   const messageHash = TypedDataUtils.hashStruct(typedData, typedData.primaryType, typedData.message)
  //   const messageHashHex = ethers.utils.hexlify(messageHash)
  //   mlog.log('messageHash (calculated)', messageHashHex)
    
  //   const message2Hash = keccak256(message)
  //   mlog.log('messageHash (calculated 2)', message2Hash)
    
  //   mlog.log('rlp', JSON.stringify(rlp))
  //   mlog.log('recover', ethers.utils.recoverAddress(messageDigest, sig))
  //   assert(await pool.validateAcceptTokens(user1, tokens, secretHash, rlp.v, rlp.r, rlp.s, true, { from: user1 }), 'invalid signature')
  //   mlog.log('account info: ', JSON.stringify(await pool.account(user1), { from: user1 }))
  //   await pool.executeAcceptTokens(user1, tokens, Buffer.from(secret), rlp.v, rlp.r, rlp.s, true, { from: poolOwner} )
  //   mlog.log('account info: ', JSON.stringify(await pool.account(user1), { from: user1 }))
  })
  
  
});
