'use strict';

const Backupable = artifacts.require("Backupable");
const Factory = artifacts.require("Factory");
const FactoryProxy = artifacts.require("FactoryProxy");
const Wallet = artifacts.require("Wallet");
const Oracle = artifacts.require("Oracle");
const { ZERO_ADDRESS } = require('./lib/consts');

const backupableTests = require('./backupableTests');
backupableTests(async (factoryOwner1, factoryOwner2, factoryOwner3, walletOwner) => {
    const sw_factory = await Factory.new({ from: factoryOwner1 });
    const sw_factory_proxy = await FactoryProxy.new(ZERO_ADDRESS, { from: factoryOwner1 });
    await sw_factory_proxy.setTarget(sw_factory.address, { from: factoryOwner1 });
    const factory = await Factory.at(sw_factory_proxy.address, { from: factoryOwner1 });
    const swver = await Wallet.new({ from: factoryOwner1 });
    const oracle = await Oracle.new(factoryOwner1, factoryOwner2, factoryOwner3, { from: factoryOwner1 });
    await oracle.setPaymentAddress(factoryOwner2, { from: factoryOwner1 });
    await oracle.setPaymentAddress(factoryOwner2, { from: factoryOwner2 });
    await factory.addVersion(swver.address, oracle.address, { from: factoryOwner1 });
    await factory.deployVersion(await swver.version(), { from: factoryOwner1 });
    await factory.createWallet(true, { from: walletOwner });
    const sw = await factory.getWallet(walletOwner);
    return Backupable.at(sw);
}, "Backupable", 1);
