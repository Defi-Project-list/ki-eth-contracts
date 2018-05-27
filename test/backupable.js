const Backupable = artifacts.require("Backupable");
const mlog = require('mocha-logger');
const { ZERO_ADDRESS, ZERO_BN } = require('./lib/consts');
const {
  assertRevert,
  assertInvalidOpcode,
  assertPayable,
  assertFunction,
  assetEvent_getArgs
} = require('./lib/asserts');

console.log("Using web3 '" + web3.version.api + "'");

const ownableTests = require('./ownableTests');
ownableTests(Backupable, "Backupable as Ownable");

const backupableTests = require('./backupableTests');
backupableTests(Backupable, "Backupable");
