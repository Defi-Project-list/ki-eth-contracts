'use strict';


// var ENS = artifacts.require("ens/ENS")
// const ENS = artifacts.require("ens/ENS");

// const ENSRegistry = artifacts.require('ens/ENSRegistry');
// const FIFSRegistrar = artifacts.require('ens/FIFSRegistrar');
const SIGN_WITH_METAMASK = false

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
  let FACTORY_DOMAIN_SEPARATOR;
  const factoryOwner1 = accounts[0];
  const factoryOwner2 = accounts[1];
  const factoryOwner3 = accounts[2];
  const owner         = accounts[3];
  const user1         = accounts[4];
  const user2         = accounts[5];
  const user3         = accounts[6];
  const operator      = accounts[7];
  const user4         = accounts[8];
  const activator     = accounts[7];
  const instances     = []
  
  const val1  = web3.utils.toWei('0.5', 'gwei');
  const val2  = web3.utils.toWei('0.4', 'gwei');
  const val3  = web3.utils.toWei('0.6', 'gwei');
  const valBN = web3.utils.toBN(val1).add(web3.utils.toBN(val2)).add(web3.utils.toBN(val3));

  const gas = 7000000
  const userCount = 2

  console.log('accounts', JSON.stringify(accounts))
  const getPrivateKey = (address) => {
    //  const wallet = web3.currentProvider.wallets[address.toLowerCase()]
    //  console.log(`0x${wallet.privateKey.toString('hex')}`)
    //  return `0x${wallet.privateKey.toString('hex')}`

    if (address === owner) {
      return '0x5f055f3bc7f2c8cabcc5132d97d6b594c25becbc57139221f1ef89263efc99c7' // `0x${wallet._privKey.toString('hex')}`
    }
    if (address === operator) {
      return '0xf2eb3ee5aca80df482e9b6474f6af69b1186766ba10faf59a761aaa04ff405d0'
    }
    if (address === accounts[10]) {
      return '0x557bca6ef564e9573c073ca84c6b8093063221807abc5abf784b9c0ad1cc94a1'
    }
    if (address === accounts[11]) {
      return '0x90f789c3b13f709b8638f8641e5123cc06e540e5dcc34287b820485c1948b9f5'
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
  
  const eip712sign = async (inst, typedData, account) => {
    mlog.log('typedData: ', JSON.stringify(typedData, null, 2))
    const domainHash = TypedDataUtils.hashStruct(typedData, 'EIP712Domain', typedData.domain)
    const domainHashHex = ethers.utils.hexlify(domainHash)
    mlog.log('CHAIN_ID', await inst.CHAIN_ID())
    mlog.log('DOMAIN_SEPARATOR', await inst.DOMAIN_SEPARATOR())
    mlog.log('DOMAIN_SEPARATOR (calculated)', domainHashHex)

    const messageDigest = TypedDataUtils.encodeDigest(typedData)
    const messageDigestHex = ethers.utils.hexlify(messageDigest)

    console.log('message:', messageDigestHex)  

    console.log('data:', ethers.utils.hexlify(TypedDataUtils.encodeData(typedData, typedData.primaryType, typedData.message)))

    let rlp, signature

    if (SIGN_WITH_METAMASK) {
      signature = await new Promise(resolve => socket.emit('sign request', JSON.stringify([typedData]), resolve))
      rlp = { r: signature.slice(0, 66), s: '0x'+signature.slice(66,130), v: '0x'+signature.slice(130) }

    } else {
      const signingKey = new ethers.utils.SigningKey(getPrivateKey(accounts[account]));
      signature = signingKey.signDigest(messageDigest)
      rlp = ethers.utils.splitSignature(signature)
      rlp.v = '0x' + rlp.v.toString(16)
    }

    const messageHash = TypedDataUtils.hashStruct(typedData, typedData.primaryType, typedData.message)
    const messageHashHex = ethers.utils.hexlify(messageHash)
    // mlog.log('messageHash (calculated)', messageHashHex)

    // const m = keccak256(toUtf8Bytes('batchCall(address activator,address to,uint256 value,uint256 nonce,bytes4 selector,address recipient,uint256 amount)'))
    // mlog.log('m (calculated)', m)

    const m2 = TypedDataUtils.typeHash(typedData.types, typedData.primaryType)
    const m2Hex = ethers.utils.hexZeroPad(ethers.utils.hexlify(m2), 32)
    console.log('m2 (calculated)', m2Hex)

    mlog.log('rlp', JSON.stringify(rlp))
    mlog.log('recover', ethers.utils.recoverAddress(messageDigest, signature))
    // await utils.sleep(10 * 1000)
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

    const sw_factory = await Factory.new({ from: owner, nonce: await web3.eth.getTransactionCount(owner) })
    .on('receipt', function(receipt){ mlog.pending(`Creating Factory Cost ${receipt.gasUsed} gas`) })
    const sw_factory_proxy = await FactoryProxy.new(ZERO_ADDRESS, { from: owner })
    .on('receipt', function(receipt){ mlog.pending(`Creating Factory Proxy Cost ${receipt.gasUsed} gas`) })

    /// await ens.setAddress('user10.eth', accounts[10])
    await sw_factory_proxy.setTarget(sw_factory.address, { from: owner });
    
    factory = await Factory.at(sw_factory_proxy.address);
    factoryProxy = await FactoryProxy.at(sw_factory_proxy.address);

    const version = await Wallet.new({ from: factoryOwner3 });
    oracle = await Oracle.new(factoryOwner1, factoryOwner2, factoryOwner3, {from: owner, nonce: await web3.eth.getTransactionCount(owner)});
    await oracle.setPaymentAddress(factoryOwner2, { from: factoryOwner2 });
    await oracle.setPaymentAddress(factoryOwner2, { from: factoryOwner1 });
    await factory.addVersion(version.address, oracle.address, { from: owner });
    await factory.deployVersion(await version.version(), { from: owner });
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

    await factoryProxy.setActivator(activator, { from: owner });

    await factoryProxy.setLocalEns("token.kiro.eth", token20.address, { from: owner });

    FACTORY_DOMAIN_SEPARATOR = (await factoryProxy.DOMAIN_SEPARATOR())

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
  
  it('eip712: should be able to execute external calls', async () => {

      const msg = (await factory.generateMessage.call("Please sign", "Thanks", true))

      const typedData = [{ 
          type: "string",
          name: "message", 
          value: msg
      }]

      mlog.log(JSON.stringify(msg))

      const signature = await new Promise(resolve => socket.emit('sign_v1 request', JSON.stringify([typedData]), resolve))
      const rlp = { r: signature.slice(0, 66), s: '0x'+signature.slice(66,130), v: '0x'+signature.slice(130) }



    // const tokens = 2
    // await instance.cancelCall({ from: owner })
    // const data = token20.contract.methods.transfer(user1, 5).encodeABI()

    // mlog.log('---> data', data)

    // const typedData = {
    //   types: {
    //     EIP712Domain: [
    //       { name: "name",               type: "string" },
    //       { name: "version",            type: "string" },
    //       { name: "chainId",            type: "uint256" },
    //       { name: "verifyingContract",  type: "address" },
    //       { name: "salt",               type: "bytes32" }
    //     ],
    //     executeCall: [
    //       { name: 'activator',          type: 'address' },
    //       { name: 'contract',           type: 'address' },
    //       { name: 'eth',                type: 'uint256' },
    //       { name: 'nonce',              type: 'uint256' },
    //       { name: 'staticCall',         type: 'bool'    },
    //       { name: 'gasLimit',           type: 'uint32'  },
    //       { name: 'selector',           type: 'bytes4' },
    //       { name: 'trStart',            type: 'uint256' },
    //       { name: 'trLength',           type: 'uint256' },
    //       { name: 'recipient',          type: 'address' },
    //       { name: 'amount',             type: 'uint256' },
    //     ]
    //   },
    //   primaryType: 'executeCall',
    //   domain: {
    //     name: await instance.NAME(),
    //     version: await instance.VERSION(),
    //     chainId: '0x' + web3.utils.toBN(await instance.CHAIN_ID()).toString('hex'), // await web3.eth.getChainId(),
    //     verifyingContract: instance.address,
    //     salt: await instance.uid(),
    //   },
    //   message: {
    //     activator,
    //     contract: token20.address,
    //     eth: '0',
    //     nonce: (await instance.nonce()).toString(),
    //     staticCall: false,
    //     gasLimit: '0',
    //     selector: '0x' + data.slice(2,10),
    //     trStart: '288', // 9*32
    //     trLength: '64',
    //     recipient: user1,
    //     amount: '5',
    //   }
    // }

    // mlog.log('typedData: ', JSON.stringify(typedData, null, 2))
    // const domainHash = TypedDataUtils.hashStruct(typedData, 'EIP712Domain', typedData.domain)
    // const domainHashHex = ethers.utils.hexlify(domainHash)
    // mlog.log('CHAIN_ID', await instance.CHAIN_ID())
    // mlog.log('DOMAIN_SEPARATOR', await instance.DOMAIN_SEPARATOR())
    // mlog.log('DOMAIN_SEPARATOR (calculated)', domainHashHex)

    // const messageDigest = TypedDataUtils.encodeDigest(typedData)
    // const messageDigestHex = ethers.utils.hexlify(messageDigest)
    // let signingKey = new ethers.utils.SigningKey(getPrivateKey(owner));
    // const sig = signingKey.signDigest(messageDigest)
    // const rlp = ethers.utils.splitSignature(sig)
    // rlp.v = '0x' + rlp.v.toString(16)
  
    // const messageHash = TypedDataUtils.hashStruct(typedData, typedData.primaryType, typedData.message)
    // const messageHashHex = ethers.utils.hexlify(messageHash)
    // mlog.log('messageHash (calculated)', messageHashHex)

    // const m = keccak256(toUtf8Bytes('executeCall(address activator,address to,uint256 value,uint256 nonce,bytes4 selector,address recipient,uint256 amount)'))
    // mlog.log('m (calculated)', m)

    // const m2 = TypedDataUtils.typeHash(typedData.types, 'executeCall')
    // const m2Hex = ethers.utils.hexZeroPad(ethers.utils.hexlify(m2), 32)
    // mlog.log('m2 (calculated)', m2Hex)

    // mlog.log('rlp', JSON.stringify(rlp))
    // mlog.log('recover', ethers.utils.recoverAddress(messageDigest, sig))

    // const balance = await token20.balanceOf(user1, { from: user1 })

    // const { receipt } = await instance.executeBatchCall([{ v: rlp.v, r: rlp.r, s: rlp.s, typeHash: m2Hex, to: token20.address, value: 0, metaData: { simple: false, staticcall: false, gasLimit: 0 }, data: data }], { from: activator })
    // const diff = (await token20.balanceOf(user1)).toNumber() - balance.toNumber()
    // assert.equal (diff, 5, 'user1 balance change')
    // mlog.pending(`ERC20 Transfer consumed ${JSON.stringify(receipt.gasUsed)} gas`)
  })


  

});
