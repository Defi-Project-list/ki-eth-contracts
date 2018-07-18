const Backupable = artifacts.require("Backupable");

const backupableTests = require('./backupableTests');
backupableTests(Backupable, "Backupable");
