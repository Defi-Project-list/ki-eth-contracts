const Backupable = artifacts.require("Backupable");
const mlog = require('mocha-logger');

console.log("Using web3 '" + web3.version.api + "'");

const ownableTests = require('./ownableTests');
ownableTests(Backupable, "Backupable as Ownable");

const backupableTests = require('./backupableTests');
backupableTests(Backupable, "Backupable");
