const Backupable = artifacts.require("Backupable");
const Heritable = artifacts.require("Heritable");

const backupableTests = require('./backupableTests');
backupableTests(Heritable, "Heritable as Backupable");

const heritableTests = require('./heritableTests');
heritableTests(Heritable, "Heritable");
