const Trust = artifacts.require("Trust");

const trustTests = require('./trustTests');
trustTests(Trust, "Trust");
