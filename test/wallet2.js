'use strict';


// var ENS = artifacts.require("ens/ENS")
// const ENS = artifacts.require("ens/ENS");

// const ENSRegistry = artifacts.require('ens/ENSRegistry');
// const FIFSRegistrar = artifacts.require('ens/FIFSRegistrar');
const SIGN_WITH_METAMASK = false

const MultiSigWallet = artifacts.require("MultiSigWallet")
const Wallet = artifacts.require("Wallet")
const Oracle = artifacts.require("Oracle")
const Factory = artifacts.require("Factory")
const FactoryProxy = artifacts.require("FactoryProxy")
const ERC20Token = artifacts.require("ERC20Token")
const ERC721Token = artifacts.require("ERC721Token")
const mlog = require('mocha-logger')
const { ZERO_ADDRESS, ZERO_BYTES32, ZERO_BN } = require('./lib/consts')

const io = require('socket.io-client')

const utils = require('./lib/utils');

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
  let multiSig;
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
    // const wallet = web3.currentProvider.wallets[address.toLowerCase()]
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
    return accounts[index]
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
    if (SIGN_WITH_METAMASK) {
      await utils.sleep(10 * 1000)
    }
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
    multiSig = await MultiSigWallet.new(factoryOwner1, factoryOwner2, factoryOwner3)

    const sw_factory = await Factory.new(factoryOwner1, factoryOwner2, factoryOwner3, { from: owner, nonce: await web3.eth.getTransactionCount(owner) })
    .on('receipt', function(receipt){ mlog.pending(`Creating Factory Cost ${receipt.gasUsed} gas`) })
    const sw_factory_proxy = await FactoryProxy.new(factoryOwner1, factoryOwner2, factoryOwner3, ZERO_ADDRESS, { from: owner })
    .on('receipt', function(receipt){ mlog.pending(`Creating Factory Proxy Cost ${receipt.gasUsed} gas`) })

    await sw_factory_proxy.transferOwnership(multiSig.address, { from: owner })
    /// await ens.setAddress('user10.eth', accounts[10])
    // const sw_factory = await Factory.new(factoryOwner1, factoryOwner2, factoryOwner3, { from: owner, nonce: await web3.eth.getTransactionCount(owner) })
    // const sw_factory_proxy = await FactoryProxy.new(factoryOwner1, factoryOwner2, factoryOwner3, { from: owner })
    await multiSig.setOwnTarget_(sw_factory_proxy.address, { from: factoryOwner1 })
    await multiSig.setOwnTarget_(sw_factory_proxy.address, { from: factoryOwner2 })

    const sw_factory_proxy_ms = await FactoryProxy.at(multiSig.address)

    await sw_factory_proxy_ms.setTarget(sw_factory.address, { from: factoryOwner1 });
    await sw_factory_proxy_ms.setTarget(sw_factory.address, { from: factoryOwner2 });
    
    factory = await Factory.at(sw_factory_proxy.address);
    factoryProxy = await FactoryProxy.at(sw_factory_proxy.address);

    // const factory = await FactoryProxy.new({ from: creator });
    const version = await Wallet.new({ from: factoryOwner3 });
    oracle = await Oracle.new(factoryOwner1, factoryOwner2, factoryOwner3, {from: owner, nonce: await web3.eth.getTransactionCount(owner)});
    await oracle.setPaymentAddress(factoryOwner2, { from: factoryOwner2 });
    await oracle.setPaymentAddress(factoryOwner2, { from: factoryOwner1 });
    //await factory.addVersion(web3.fromAscii("1.1", 8), version.address, { from: creator });
    
    await multiSig.setOwnTarget_(factory.address, { from: factoryOwner1 })
    await multiSig.setOwnTarget_(factory.address, { from: factoryOwner2 })

    const factory_ms = await Factory.at(multiSig.address)

    await factory_ms.addVersion(version.address, oracle.address, { from: factoryOwner3 });
    await factory_ms.addVersion(version.address, oracle.address, { from: factoryOwner1 });
    await factory_ms.deployVersion(await version.version(), { from: factoryOwner1 });
    await factory_ms.deployVersion(await version.version(), { from: factoryOwner2 });
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

    // await factoryProxy.setOperator(operator, { from: factoryOwner1 });
    // await factoryProxy.setOperator(operator, { from: factoryOwner2 });
    
    await multiSig.setOwnTarget_(sw_factory_proxy.address, { from: factoryOwner1 })
    await multiSig.setOwnTarget_(sw_factory_proxy.address, { from: factoryOwner2 })

    await sw_factory_proxy_ms.setActivator(activator, { from: factoryOwner1 });
    await sw_factory_proxy_ms.setActivator(activator, { from: factoryOwner2 });

    await sw_factory_proxy_ms.setLocalEns("token.kiro.eth", token20.address, { from: factoryOwner1 });
    await sw_factory_proxy_ms.setLocalEns("token.kiro.eth", token20.address, { from: factoryOwner2 });

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
    for (let i=10; i<20; /*10+userCount/2;*/ ++i) {
      const { receipt } = await factory.createWallet(false, { from: accounts[i] });
      mlog.pending(`Creating Wallet for ${accounts[i]} Cost ${JSON.stringify(receipt.gasUsed)} gas`)
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
  

it('EIP712: should be able to execute multi external calls: signer==operator, sender==owner', async () => {
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
//1
        {
          data: token20.contract.methods.transfer(accounts[11], 5).encodeABI(),
          value: 0,
          // typeHash: '0x'.padEnd(66,'1'),
          to: token20.address,
          gasLimit: 0,
          // flow: 0x10, // on_success_stop
        },
        // {
        //   data: token20.contract.methods.transfer(accounts[11], 5).encodeABI(),
        //   value: 0,
        //   // typeHash: '0x'.padEnd(66,'1'),
        //   to: token20.address,
        //   gasLimit: 0,
        //   // flow: 0x10, // on_success_stop
        // },
//2
        {
          data: '',
          value: 10,
          // typeHash: '0x'.padEnd(66,'1'),
          to: accounts[11],
          gasLimit: 0,
        },
//3        
        {
          data: token20.contract.methods.transfer(accounts[13], 12).encodeABI(),
          value: 0,
          // typeHash: '0x'.padEnd(66,'1'),
          to: token20.address,
          gasLimit: 0,
        },
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


    const groupERC20        = '000008'
    const tnonceERC20       = '0000000200'
    const afterERC20        = '0000000000'
    const beforeERC20       = 'ffffffffff'
    const maxGasERC20       = '00000000'
    const maxGasPriceERC20  = '00000000000000c8'
    const eip712ERC20       = 'f100' // not-ordered, payment, eip712

    const getSessionIdERC20 = (index, staticcall) => (
      `0x${groupERC20}${tnonceERC20}${afterERC20}${beforeERC20}${maxGasERC20}${maxGasPriceERC20}${eip712ERC20}`
    )

        const typedData = {
      types: {
        EIP712Domain: [
          { name: "name",                 type: "string"  },
          { name: "version",              type: "string"  },
          { name: "chainId",              type: "uint256" },
          { name: "verifyingContract",    type: "address" },
          { name: "salt",                 type: "bytes32" },
        ],
        BatchMultiCall: [
          { name: 'limits',               type: 'Limits'},
          { name: 'transaction_1',        type: 'TokenTransfer' },
          { name: 'transaction_2',        type: 'EthTransfer' }, //TODO: check is there is bug/limit in metamsk
          { name: 'transaction_3',        type: 'TokenTransfer' }, 
        ],
        Limits: [
          { name: 'nonce',                type: 'uint64'      },
          { name: 'ordered',              type: 'bool'        },
          { name: 'refund',               type: 'bool'        },
          { name: 'valid_from',           type: 'uint40'      },
          { name: 'expires_at',           type: 'uint40'      },
          { name: 'gas_price_limit',      type: 'uint64'      },
        ],
        Transaction: [
          { name: 'call_address',         type: 'address'     },
          { name: 'call_ens',             type: 'string'      },
          { name: 'eth_value',            type: 'uint256'     },
          { name: 'gas_limit',            type: 'uint32'      },
          { name: 'view_only',            type: 'bool'        },
          { name: 'continue_on_fail',     type: 'bool'        },
          { name: 'stop_on_fail',         type: 'bool'        },
          { name: 'stop_on_success',      type: 'bool'        },
          { name: 'revert_on_success',    type: 'bool'        },
          { name: 'method_interface',     type: 'string'      },        
        ],
        TokenTransfer: [
          { name: 'details',              type: 'Transaction' },
          { name: 'method_params_offset', type: 'uint256'     },
          { name: 'method_params_length', type: 'uint256'     },
          { name: 'to',                   type: 'address'     },
          { name: 'token_amount',         type: 'uint256'     },
        ],
        EthTransfer: [
          { name: 'details',              type: 'Transaction' },
        ],
      },
      primaryType: 'BatchMultiCall',
      domain: {
        name: await factoryProxy.NAME(),
        version: await factoryProxy.VERSION(),
        chainId: '0x' + web3.utils.toBN(await factoryProxy.CHAIN_ID()).toString('hex'), // await web3.eth.getChainId(),
        verifyingContract: factoryProxy.address,
        salt: await factoryProxy.uid(),
      },
      message: { 
        ['KIROBO PROTECTS YOU']: '👍',
        ['MULTI PROTECTION']: '👍',
        limits: {
          nonce: '0x' + groupERC20 + tnonceERC20,
          ordered: false,
          refund: true,
          valid_from: Number.parseInt('0x' + afterERC20),
          expires_at: Number.parseInt('0x' + beforeERC20),
          gas_price_limit: Number.parseInt('0x' + maxGasPriceERC20),
        },
        ['-----------------------------------']: '',
        transaction_1: {
          details: {
            call_address: token20.address,
            call_ens: '@token.kiro.eth',
            eth_value: '0',
            view_only: false,
            continue_on_fail: false,
            stop_on_fail: false,
            stop_on_success: false,
            revert_on_success: false,
            gas_limit: Number.parseInt('0x' + maxGasERC20),
            method_interface: 'transfer(address,uint256)',
          },
          method_params_offset: '0x60', //'0x180', // '480', // 13*32
          method_params_length: '0x40',
          to: accounts[11],
          token_amount: '5',
      },
        ['------------------------------------']: '',
      //   transaction_2: {
      //     details: {
      //       call_address: token20.address,
      //       call_ens: '@token.kiro.eth',
      //       eth_value: '0',
      //       view_only: false,
      //       continue_on_fail: false,
      //       stop_on_fail: false,
      //       stop_on_success: false,
      //       revert_on_success: false,
      //       gas_limit: Number.parseInt('0x' + maxGasERC20),
      //       method_interface: 'transfer(address,uint256)',
      //     },
      //     method_params_offset: '0x60', //'0x180', // '480', // 13*32
      //     method_params_length: '0x40',
      //     to: accounts[11],
      //     token_amount: '5',
      // },
      transaction_2: {
        details: {
          call_address: accounts[11],
          call_ens: '',
          eth_value: '10',
          view_only: false,
          continue_on_fail: false,
          stop_on_fail: false,
          stop_on_success: false,
          revert_on_success: false,
          gas_limit: Number.parseInt('0x' + maxGasERC20),
          method_interface: '',
        }
      }, 
        ['-------------------------------------']: '', 
        transaction_3: {
          details: {
            call_address: token20.address,
            call_ens: '@token.kiro.eth',
            eth_value: '0',
            gas_limit: Number.parseInt('0x' + maxGasERC20),
            view_only: false,
            continue_on_fail: false,
            stop_on_fail: false,
            stop_on_success: false,
            revert_on_success: false,
            method_interface: 'transfer(address,uint256)',
          },
          method_params_offset: '0x60', // '0x180', // '480', // 13*32
          method_params_length: '0x40',
          to: accounts[13],
          token_amount: '12',
      }}
    }



    // console.log('sends', JSON.stringify(sends, null,2))

    const msgDataERC20 = sends.map((send, index) => ({
        mcall: send.map((item, index) => ({
              ...item,
              typeHash: TypedDataUtils.typeHash(typedData.types, typedData.types.BatchMultiCall[index+1].type),
              flags: (item.flow ? item.flow : 0) + (item.stataiccall ? 4*256 : 0),
              functionSignature: item.data.length > 0 ? web3.utils.sha3('transfer(address,uint256)') : '0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470',
              gasLimit: Number.parseInt('0x' + maxGasERC20),
              ensHash: item.data.length > 0 ? web3.utils.sha3('@token.kiro.eth'): '0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470',
              data: item.data.length > 0 ? '0x' + item.data.slice(10): '0x'})
        ), 
        // _hash: defaultAbiCoder.encode(
        //   ['(bytes32,address,uint256,uint256,uint40,uint40,uint256,uint256,bytes4,bytes)[]'],
        //   [send.map(item => ([ 
        //         item.typeHash,
        //         item.to,
        //         item.value,
        //         getSessionIdERC20(index, item.staticcall),
        //         '0x'+afterERC20,
        //         '0x'+beforeERC20,
        //         '0x'+maxGasERC20,
        //         '0x'+maxGasPriceERC20,
        //         item.data.slice(0, 10),
        //         '0x' + item.data.slice(10),
        //       ]))
        //   ]
        // )
          // ['bytes32','address','uint256','uint256','uint40','uint40','uint256','bytes4','bytes'],
          // [item.typeHash, item.to, item.value, getSessionIdERC20(index), '0x'+afterERC20, '0x'+beforeERC20, '0x'+maxGasPriceERC20, item.data.slice(0, 10), '0x' + item.data.slice(10)])
    }))


    // console.log('msgDataERC20:', JSON.stringify(msgDataERC20, null, 2))
    // const metaData = { simple: true, staticcall: false, gasLimit: 0 }

    const msgsERC20 = (await Promise.all(msgDataERC20.map(async (item, index) => ({
      ...item,
      // ...await web3.eth.accounts.sign(web3.utils.sha3(item._hash), keys[index+10] /*getPrivateKey(owner)*/),
      ...await eip712sign(factoryProxy, typedData, 10),
      typeHash: eip712typehash(typedData),
      limitsTypeHash: TypedDataUtils.typeHash(typedData.types, 'Limits'),
      sessionId: getSessionIdERC20(10, false),
      signer: getSigner(10),
      // _hash: undefined,
    })))) // .map(item=> ({...item, sessionId: item.sessionId + item.v.slice(2).padStart(2,'0') }))

    const balance = await token20.balanceOf(user1, { from: user1 })
    // mlog.pending(`calling ${JSON.stringify(msgsERC20, null, 2)}`)

    await logERC20Balances()
    await logBalances()

    const { receipt: receiptERC20 } = await factoryProxy.batchMultiCall(msgsERC20, 8, { from: activator, gasPrice: 200, gas: 1e6 }) // .catch(revertReason => console.log({ revertReason: JSON.stringify(revertReason, null ,2) }))

    mlog.pending(`ERC20 X ${msgsERC20.length} Transfers consumed ${JSON.stringify(receiptERC20.gasUsed)} gas (${JSON.stringify(receiptERC20.gasUsed/msgsERC20.length)} gas per call)`)

    await logERC20Balances()
    await logBalances()
    await logDebt()

  })

const runEIP712MultiSigTest= async (multiSig, group) => {
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
          data: token20.contract.methods.transfer(accounts[11], 5).encodeABI(),
          value: 0,
          // typeHash: '0x'.padEnd(66,'1'),
          to: token20.address,
          gasLimit: 0,
          signer: getSigner(10),
          // flow: 0x10, // on_success_stop
        },
        (multiSig ? 
        {
          data: '',
          value: 0,
          // typeHash: '0x'.padEnd(66,'1'),
          to: ZERO_ADDRESS,
          gasLimit: 0,
          signer: getSigner(11),
        }:
        {
          data: '',
          value: 10,
          // typeHash: '0x'.padEnd(66,'1'),
          to: accounts[12],
          gasLimit: 0,
          signer: getSigner(11),
        }),
        {
          data: token20.contract.methods.transfer(accounts[13], 12).encodeABI(),
          value: 0,
          // typeHash: '0x'.padEnd(66,'1'),
          to: token20.address,
          gasLimit: 0,
          signer: getSigner(10),
        },
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


    const groupERC20        = '0000' + group
    const tnonceERC20       = '0000000200'
    const afterERC20        = '0000000000'
    const beforeERC20       = 'ffffffffff'
    const maxGasERC20       = '00000000'
    const maxGasPriceERC20  = '00000000000000c8'
    const eip712ERC20       = 'f100' // not-ordered, payment, eip712

    const getSessionIdERC20 = (index, staticcall) => (
      `0x${groupERC20}${tnonceERC20}${afterERC20}${beforeERC20}${maxGasERC20}${maxGasPriceERC20}${eip712ERC20}`
    )

    const transaction2 = multiSig ? 
          { name: 'approval',             type: 'Approval'}:
          { name: 'transaction_2',        type: 'transaction2'}
    
    const typedData = {
      types: {
        EIP712Domain: [
          { name: "name",                 type: "string"  },
          { name: "version",              type: "string"  },
          { name: "chainId",              type: "uint256" },
          { name: "verifyingContract",    type: "address" },
          { name: "salt",                 type: "bytes32" },
        ],
        BatchMultiSigCall: [
          { name: 'limits',                 type: 'Limits'},
          { name: 'transaction_1',          type: 'transaction1'},
          transaction2,
          { name: 'transaction_3',          type: 'transaction3'},
        ],
        Limits: [
          { name: 'nonce',                type: 'uint64'  },
          { name: 'ordered',              type: 'bool'    },
          { name: 'refund',               type: 'bool'    },
          { name: 'valid_from',           type: 'uint40'  },
          { name: 'expires_at',           type: 'uint40'  },
          { name: 'gas_price_limit',      type: 'uint64'  },
        ],
        transaction1: [
          { name: 'details',              type: 'Transaction' },
          { name: 'method_data_offset',   type: 'uint256' },
          { name: 'method_data_length',   type: 'uint256' },
          { name: 'to',                   type: 'address' },
          { name: 'token_amount',         type: 'uint256' },
        ],
        transaction2: [
          { name: 'details',              type: 'Transaction' },
        ],
        transaction3: [
          { name: 'details',              type: 'Transaction' },
          { name: 'method_data_offset',   type: 'uint256' },
          { name: 'method_data_length',   type: 'uint256' },
          { name: 'to',                   type: 'address' },
          { name: 'token_amount',         type: 'uint256' },
        ],
        Transaction: [
          { name: 'signer',               type: 'address'     },
          { name: 'call_address',         type: 'address'     },
          { name: 'call_ens',             type: 'string'      },
          { name: 'eth_value',            type: 'uint256'     },
          { name: 'gas_limit',            type: 'uint32'      },
          { name: 'view_only',            type: 'bool'        },
          { name: 'continue_on_fail',     type: 'bool'        },
          { name: 'stop_on_fail',         type: 'bool'        },
          { name: 'stop_on_success',      type: 'bool'        },
          { name: 'revert_on_success',    type: 'bool'        },
          { name: 'method_interface',     type: 'string'      },        
        ],
        Approval: [
          { name: 'signer',               type: 'address'     },
        ]
      },
      primaryType: 'BatchMultiSigCall',
      domain: {
        name: await factoryProxy.NAME(),
        version: await factoryProxy.VERSION(),
        chainId: '0x' + web3.utils.toBN(await factoryProxy.CHAIN_ID()).toString('hex'), // await web3.eth.getChainId(),
        verifyingContract: factoryProxy.address,
        salt: await factoryProxy.uid(),
      },
      message: { 
        ['KIROBO PROTECTS YOU']: '👍',
        ['MULTI PROTECTION']: '👍',
        limits: {
          nonce: '0x' + groupERC20 + tnonceERC20,
          ordered: false,
          refund: true,
          valid_from: Number.parseInt('0x' + afterERC20),
          expires_at: Number.parseInt('0x' + beforeERC20),
          gas_price_limit: Number.parseInt('0x' + maxGasPriceERC20),
        },
        ['-----------------------------------']: '',
        transaction_1: {
          details: {
            signer: getSigner(10), 
            call_address: token20.address,
            call_ens: '@token.kiro.eth',
            eth_value: '0',
            view_only: false,
            continue_on_fail: false,
            stop_on_fail: false,
            stop_on_success: false,
            revert_on_success: false,
            gas_limit: Number.parseInt('0x' + maxGasERC20),
            method_interface: 'transfer(address,uint256)',
          },
          method_data_offset: '0x60', //'0x1a0', // '480', // 13*32
          method_data_length: '0x40',
          to: accounts[11],
          token_amount: '5',
      },
        ['------------------------------------']: '',
        approval: {
          signer: getSigner(11),
        },
        transaction_2: {
          details: {
            signer: getSigner(11),
            call_address: multiSig ? ZERO_ADDRESS: accounts[12],
            call_ens: '',
            eth_value: multiSig ? '0': '10',
            gas_limit: Number.parseInt('0x' + maxGasERC20),
            view_only: false,
            continue_on_fail: false,
            stop_on_fail: false,
            stop_on_success: false,
            revert_on_success: false,
            method_interface: '',
          },
        }, 
        ['-------------------------------------']: '', 
        transaction_3: {
          details: {
            signer: getSigner(10),
            call_address: token20.address,
            call_ens: '@token.kiro.eth',
            eth_value: '0',
            gas_limit: Number.parseInt('0x' + maxGasERC20),
            view_only: false,
            continue_on_fail: false,
            stop_on_fail: false,
            stop_on_success: false,
            revert_on_success: false,
            method_interface: 'transfer(address,uint256)',
          },
          method_data_offset: '0x60', //'0x1a0', // '480', // 13*32
          method_data_length: '0x40',
          to: accounts[13],
          token_amount: '12',
      }}
    }

    // console.log('sends', JSON.stringify(sends, null,2))

    const msgDataERC20 = sends.map((send, index) => ({
        mcall: send.map((item, index) => ({
              ...item,
              typeHash: TypedDataUtils.typeHash(typedData.types, 'transaction'+(index+1)),
              flags: (item.flow ? item.flow : 0) + (item.stataiccall ? 4*256 : 0),
              // selector: item.data.slice(0, 10),
              functionSignature: item.data.length > 0 ? web3.utils.sha3('transfer(address,uint256)') : '0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470',
              gasLimit: Number.parseInt('0x' + maxGasERC20),
              ensHash: item.data.length > 0 ? web3.utils.sha3('@token.kiro.eth'): '0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470',
              data: item.data.length > 0 ? '0x' + item.data.slice(10): '0x'})
        ), 
        // _hash: defaultAbiCoder.encode(
        //   ['(bytes32,address,uint256,uint256,uint40,uint40,uint256,uint256,bytes4,bytes)[]'],
        //   [send.map(item => ([ 
        //         item.typeHash,
        //         item.to,
        //         item.value,
        //         getSessionIdERC20(index, item.staticcall),
        //         '0x'+afterERC20,
        //         '0x'+beforeERC20,
        //         '0x'+maxGasERC20,
        //         '0x'+maxGasPriceERC20,
        //         item.data.slice(0, 10),
        //         '0x' + item.data.slice(10),
        //       ]))
        //   ]
        // )
          // ['bytes32','address','uint256','uint256','uint40','uint40','uint256','bytes4','bytes'],
          // [item.typeHash, item.to, item.value, getSessionIdERC20(index), '0x'+afterERC20, '0x'+beforeERC20, '0x'+maxGasPriceERC20, item.data.slice(0, 10), '0x' + item.data.slice(10)])
    }))


    // console.log('msgDataERC20:', JSON.stringify(msgDataERC20, null, 2))
    // const metaData = { simple: true, staticcall: false, gasLimit: 0 }

    const msgsERC20 = (await Promise.all(msgDataERC20.map(async (item, index) => ({
      ...item,
      // ...await web3.eth.accounts.sign(web3.utils.sha3(item._hash), keys[index+10] /*getPrivateKey(owner)*/),
      signatures: [
          {...await eip712sign(factoryProxy, typedData, 10)},
          {...await eip712sign(factoryProxy, typedData, 11)},
      ],
      typeHash: eip712typehash(typedData),
      limitsTypeHash: TypedDataUtils.typeHash(typedData.types, 'Limits'),
      sessionId: getSessionIdERC20(10, false),
      // signer: getSigner(10),
      // _hash: undefined,
    })))) // .map(item=> ({...item, sessionId: item.sessionId + item.v.slice(2).padStart(2,'0') }))

    const balance = await token20.balanceOf(user1, { from: user1 })
    // mlog.pending(`calling ${JSON.stringify(msgsERC20, null, 2)}`)

    await logERC20Balances()
    await logBalances()

    const { receipt: receiptERC20 } = await factoryProxy.batchMultiSigCall(msgsERC20, '0x'+group, { from: activator, gasPrice: 200 }) // .catch(revertReason => console.log({ revertReason: JSON.stringify(revertReason, null ,2) }))

    mlog.pending(`ERC20 X ${msgsERC20.length} Transfers consumed ${JSON.stringify(receiptERC20.gasUsed)} gas (${JSON.stringify(receiptERC20.gasUsed/msgsERC20.length)} gas per call)`)

    await logERC20Balances()
    await logBalances()
    await logDebt()

}

it('EIP712: should be able to execute multi sig external calls: signer==operator, sender==owner', async () => {
  await runEIP712MultiSigTest(false, '09')
})

it('EIP712: should be able to execute multi sig external calls with approvals: signer==operator, sender==owner', async () => {
  await runEIP712MultiSigTest(true, '0a')
})

});
