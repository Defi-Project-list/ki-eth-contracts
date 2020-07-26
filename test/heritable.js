'use strict';

const Backupable = artifacts.require("Backupable");
const Heritable = artifacts.require("Heritable");
const Factory = artifacts.require("Factory");
const FactoryProxy = artifacts.require("FactoryProxy");
const Wallet = artifacts.require("Wallet");
const Oracle = artifacts.require("Oracle");

const backupableTests = require('./backupableTests');
backupableTests(async (factoryOwner1, factoryOwner2, factoryOwner3, walletOwner) => {
  const sw_factory = await Factory.new(factoryOwner1, factoryOwner2, factoryOwner3,
    { from: factoryOwner1, nonce: await web3.eth.getTransactionCount(factoryOwner1) });
  const sw_factory_proxy = await FactoryProxy.new(factoryOwner1, factoryOwner2, factoryOwner3, { from: factoryOwner1 });
  await sw_factory_proxy.setTarget(sw_factory.address, { from: factoryOwner1 });
  await sw_factory_proxy.setTarget(sw_factory.address, { from: factoryOwner2 });
  const factory = await Factory.at(sw_factory_proxy.address, { from: factoryOwner1 });
  const swver = await Wallet.new({ from: factoryOwner1 });
  const oracle = await Oracle.new(factoryOwner1, factoryOwner2, factoryOwner3, { from: factoryOwner1 });
  await oracle.setPaymentAddress(factoryOwner2, { from: factoryOwner1 });
  await oracle.setPaymentAddress(factoryOwner2, { from: factoryOwner2 });
  await factory.addVersion(swver.address, oracle.address, { from: factoryOwner1 });
  await factory.addVersion(swver.address, oracle.address, { from: factoryOwner3 });
  await factory.deployVersion(await swver.version(), { from: factoryOwner2 });
  await factory.deployVersion(await swver.version(), { from: factoryOwner3 });
  await factory.createWallet(true, { from: walletOwner, nonce: await web3.eth.getTransactionCount(walletOwner) });
  const sw = await factory.getWallet(walletOwner);
  return Heritable.at(sw);
}, "Heritable as Backupable", 1);


const heritableTests = require('./heritableTests');
heritableTests(async (factoryOwner1, factoryOwner2, factoryOwner3, walletOwner) => {
  const sw_factory = await Factory.new(factoryOwner1, factoryOwner2, factoryOwner3,
    { from: factoryOwner1, nonce: await web3.eth.getTransactionCount(factoryOwner1) });
  const sw_factory_proxy = await FactoryProxy.new(factoryOwner1, factoryOwner2, factoryOwner3, { from: factoryOwner1 });
  await sw_factory_proxy.setTarget(sw_factory.address, { from: factoryOwner1 });
  await sw_factory_proxy.setTarget(sw_factory.address, { from: factoryOwner2 });
  const factory = await Factory.at(sw_factory_proxy.address, { from: factoryOwner1 });
  const swver = await Wallet.new({ from: factoryOwner1 });
  const oracle = await Oracle.new(factoryOwner1, factoryOwner2, factoryOwner3, { from: factoryOwner1 });
  await oracle.setPaymentAddress(factoryOwner2, { from: factoryOwner1 });
  await oracle.setPaymentAddress(factoryOwner2, { from: factoryOwner2 });
  await factory.addVersion(swver.address, oracle.address, { from: factoryOwner1 });
  await factory.addVersion(swver.address, oracle.address, { from: factoryOwner3 });
  await factory.deployVersion(await swver.version(), { from: factoryOwner2 });
  await factory.deployVersion(await swver.version(), { from: factoryOwner3 });
  await factory.createWallet(true, { from: walletOwner, nonce: await web3.eth.getTransactionCount(walletOwner) });
  const sw = await factory.getWallet(walletOwner);
  return Heritable.at(sw);
}, "Heritable");
