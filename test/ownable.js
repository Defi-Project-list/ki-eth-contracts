const Ownable = artifacts.require("Ownable");
const mlog = require('mocha-logger');

console.log("Using web3 '" + web3.version.api + "'");

const ownableTests = require('./ownableTests');
ownableTests(Ownable, "Ownable");
