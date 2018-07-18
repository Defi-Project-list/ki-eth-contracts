const Ownable = artifacts.require("Ownable");

const ownableTests = require('./ownableTests');
ownableTests(Ownable, "Ownable");
