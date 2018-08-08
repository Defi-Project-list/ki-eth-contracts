'use strict';

const Backupable = artifacts.require("Backupable");
const Heritable = artifacts.require("Heritable");
const Factory = artifacts.require("Factory");
const FactoryProxy = artifacts.require("FactoryProxy");
const Wallet = artifacts.require("Wallet");

const backupableTests = require('./backupableTests');
backupableTests(async (owner) => {
    const sw_factory = await Factory.new({ from: owner });
    const sw_factory_proxy = await FactoryProxy.new({ from: owner });
    await sw_factory_proxy.setTarget(sw_factory.address, { from: owner });
    const factory = await Factory.at(sw_factory_proxy.address, { from: owner });
    const swver = await Wallet.new();
    await factory.addVersion(swver.address, { from: owner });
    await factory.createWallet(true, { from: owner });
    const sw = await factory.getWallet(owner);
    return Heritable.at(sw);
}, "Heritable as Backupable", 1);


const heritableTests = require('./heritableTests');
heritableTests(async (owner) => {
    const sw_factory = await Factory.new({ from: owner });
    const sw_factory_proxy = await FactoryProxy.new({ from: owner });
    await sw_factory_proxy.setTarget(sw_factory.address, { from: owner });
    const factory = await Factory.at(sw_factory_proxy.address, { from: owner });
    const swver = await Wallet.new();
    await factory.addVersion(swver.address, { from: owner });
    await factory.createWallet(true, { from: owner });
    const sw = await factory.getWallet(owner);
    return Heritable.at(sw);
}, "Heritable");
