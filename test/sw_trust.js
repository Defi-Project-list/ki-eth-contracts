const SW_Trust = artifacts.require("SW_Trust");

const mlog = require('mocha-logger');

mlog.log("Using web3 '" + web3.version.api + "'");

const trustTests = require('./trustTests');
trustTests(SW_Trust, "SW_Trust");
