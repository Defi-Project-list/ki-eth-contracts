const Backupable = artifacts.require("Backupable");
const Heritable = artifacts.require("Heritable");
const mlog = require('mocha-logger');

console.log("Using web3 '" + web3.version.api + "'");

const backupableTests = require('./backupableTests');
backupableTests(Heritable, "Heritable as Backupable");

const heritableTests = require('./heritableTests');
heritableTests(Heritable, "Heritable");
