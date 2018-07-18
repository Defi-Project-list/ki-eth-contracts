const Trust = artifacts.require("Trust");

const mlog = require('mocha-logger');

mlog.log("Using web3 '" + web3.version.api + "'");

const trustTests = require('./trustTests');
trustTests(Trust, "Trust");
