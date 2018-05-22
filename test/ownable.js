const Ownable = artifacts.require("Ownable");
const mlog = require('mocha-logger');
const { ZERO_ADDRESS } = require('./lib/consts');
const {
  assertRevert,
  assertInvalidOpcode,
  assertPayable,
  assertFunction,
  assetEvent_getArgs
} = require('./lib/asserts');


console.log("Using web3 '" + web3.version.api + "'");

const ownableTests = require('./ownableTests');
ownableTests(Ownable, "Ownable");
