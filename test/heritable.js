'use strict';

const Backupable = artifacts.require("Backupable");
const Heritable = artifacts.require("Heritable");
const Factory = artifacts.require("Factory");
const FactoryProxy = artifacts.require("FactoryProxy");
const Wallet = artifacts.require("Wallet");
const Oracle = artifacts.require("Oracle");

const backupableTests = require('./backupableTests');
backupableTests(async (factoryOwner, walletOwner) => {
    const sw_factory = await Factory.new({ from: factoryOwner, nonce: await web3.eth.getTransactionCount(factoryOwner) });
    const sw_factory_proxy = await FactoryProxy.new({ from: factoryOwner });
    await sw_factory_proxy.setTarget(sw_factory.address, { from: factoryOwner });
    const factory = await Factory.at(sw_factory_proxy.address, { from: factoryOwner });
    const swver = await Wallet.new({from: factoryOwner});
    const oracle = await Oracle.new({from: factoryOwner});
    await factory.addVersion(swver.address, oracle.address, { from: factoryOwner });
    await factory.deployVersion(await swver.version(), { from: factoryOwner });
    await factory.createWallet(true, { from: walletOwner, nonce: await web3.eth.getTransactionCount(walletOwner) });
    const sw = await factory.getWallet(walletOwner);
    return Heritable.at(sw);
}, "Heritable as Backupable", 1);


const heritableTests = require('./heritableTests');
heritableTests(async (owner) => {
    const sw_factory = await Factory.new({ from: owner, nonce: await web3.eth.getTransactionCount(owner) });
    const sw_factory_proxy = await FactoryProxy.new({ from: owner });
    await sw_factory_proxy.setTarget(sw_factory.address, { from: owner });
    const factory = await Factory.at(sw_factory_proxy.address, { from: owner });
    const swver = await Wallet.new({from: owner});
    const oracle = await Oracle.new({from: owner});
    await factory.addVersion(swver.address, oracle.address, { from: owner });
    await factory.deployVersion(await swver.version(), { from: owner });
    await factory.createWallet(true, { from: owner });
    const sw = await factory.getWallet(owner);
    return Heritable.at(sw);
}, "Heritable");
