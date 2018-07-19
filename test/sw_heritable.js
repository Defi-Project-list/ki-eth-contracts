'use strict';

const SW_Backupable = artifacts.require("SW_Backupable");
const SW_Heritable = artifacts.require("SW_Heritable");
const SW_Factory = artifacts.require("SW_Factory");
const SW_FactoryProxy = artifacts.require("SW_FactoryProxy");
const SmartWallet = artifacts.require("SmartWallet");

const backupableTests = require('./backupableTests');
backupableTests(async (owner) => {
    const sw_factory = await SW_Factory.new({ from: owner });
    const sw_factory_proxy = await SW_FactoryProxy.new({ from: owner });
    await sw_factory_proxy.setTarget(sw_factory.address, { from: owner });
    const factory = await SW_Factory.at(sw_factory_proxy.address, { from: owner });
    const swver = await SmartWallet.new();
    await factory.addVersion(swver.address, { from: owner });
    await factory.createSmartWallet(true, { from: owner });
    const sw = await factory.getSmartWallet(owner);
    return SW_Heritable.at(sw);
}, "SW_Heritable as SW_Backupable");


const heritableTests = require('./heritableTests');
heritableTests(async (owner) => {
    const sw_factory = await SW_Factory.new({ from: owner });
    const sw_factory_proxy = await SW_FactoryProxy.new({ from: owner });
    await sw_factory_proxy.setTarget(sw_factory.address, { from: owner });
    const factory = await SW_Factory.at(sw_factory_proxy.address, { from: owner });
    const swver = await SmartWallet.new();
    await factory.addVersion(swver.address, { from: owner });
    await factory.createSmartWallet(true, { from: owner });
    const sw = await factory.getSmartWallet(owner);
    return SW_Heritable.at(sw);
}, "SW_Heritable");
