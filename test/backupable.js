'use strict';

const Backupable = artifacts.require("Backupable");
const Factory = artifacts.require("Factory");
const FactoryProxy = artifacts.require("FactoryProxy");
const Wallet = artifacts.require("Wallet");

const backupableTests = require('./backupableTests');
backupableTests(async (factoryOwner, walletOwner) => {
    const sw_factory = await Factory.new({ from: factoryOwner });
    const sw_factory_proxy = await FactoryProxy.new({ from: factoryOwner });
    await sw_factory_proxy.setTarget(sw_factory.address, { from: factoryOwner });
    const factory = await Factory.at(sw_factory_proxy.address, { from: factoryOwner });
    const swver = await Wallet.new();
    await factory.addVersion(swver.address, { from: factoryOwner });
    await factory.deployVersion(await swver.version(), { from: factoryOwner });
    await factory.createWallet(true, { from: walletOwner });
    const sw = await factory.getWallet(walletOwner);
    return Backupable.at(sw);
}, "Backupable", 1);
