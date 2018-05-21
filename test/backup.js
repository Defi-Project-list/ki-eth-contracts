const Backup = artifacts.require("Backup");
const mlog = require('mocha-logger');

console.log("Using web3 '" + web3.version.api + "'");

const assertRevert = (err) => {
    if (web3.version.api.startsWith("1")) {
        assert.equal('revert', Object.values(err.results)[0].error);
    }
    else {
        assert.ok(err && err.message && err.message.includes('revert'));
    }
};

const assertInvalidOpcode = (err) => {
    if (web3.version.api.startsWith("1")) {
        assert.equal('invalid opcode', Object.values(err.results)[0].error);
    }
    else{
        assert.ok(err && err.message && err.message.includes('invalid opcode'));
    }
};

describe.skip("old backup", () => {
contract('Backup', async accounts => {
  let owner = accounts[0];
  let user1 = accounts[1];
  let user2 = accounts[2];

  before('setup contract for the test', async () => {
    instance = await Backup.new();
  });

  it('should create empty backup', async () => {
    let backupWallet = await instance.getBackupWallet.call();
    assert.equal(backupWallet, 0x0);
  });

  it("owner should be able to set backup address and time", async () => {
    let res = await instance.setBackup(user2, 200, {from: owner});
    let backupWallet = await instance.getBackupWallet.call();
    assert.equal(backupWallet, user2);
  });

  it("user should not be able to set backup address or time", async () => {
      try {
        let res = await instance.setBackup(user2, 200, { from: user1 });
        let backupWallet = await instance.getBackupWallet.call();
        assert(false);
      }
      catch(err) {
          assertRevert(err);
      }
  });

  it("should revert when calling cancel", async () => {
      try {
          let res = await instance.cancel({ from: owner });
          assert(false);
      } catch (err) {
          assertRevert(err);
      }
  });
});
});
