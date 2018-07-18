const SW_Trust = artifacts.require("SW_Trust");

const trustTests = require('./trustTests');
trustTests(SW_Trust, "SW_Trust");
