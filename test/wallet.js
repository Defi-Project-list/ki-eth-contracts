const Wallet = artifacts.require("Wallet");

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

contract('Wallet', async accounts => {

  const owner = accounts[0];
  const user1 = accounts[1];
  const user2 = accounts[2];

  const val1  = web3.toWei(1.5, 'ether');
  const val2  = web3.toWei(4,   'ether');

  before('checking consts', async () => {
      assert(typeof owner == 'string', 'owner should be string');
      assert(typeof user1 == 'string', 'user1 should be string');
      assert(typeof user2 == 'string', 'user2 should be string');
      assert(typeof val1  == 'string', 'val1  should be string');
      assert(typeof val2  == 'string', 'val2  should be string');
  });

  before('setup contract for the test', async () => {
    instance = await Wallet.new();
  });

  it('should create empty wallet', async () => {
    const balance = await web3.eth.getBalance(instance.address);
    assert.equal(balance, 0x0);
  });

  it('should accept ether from everyone', async () => {
    await web3.eth.sendTransaction({ from: user1, value: val1, to: instance.address });
    const balance = await web3.eth.getBalance(instance.address);
    assert.equal(balance.toString(10), val1);
  });

  it("only owner can call getBalance", async () => {
    const balance = await instance.getBalance.call({
      from: owner
    });
    assert.equal(balance.toString(10), val1);
    try {
      const balance = await instance.getBalance.call({
        from: user1
      });
      assert(false);
    } catch (err) {
      assertRevert(err);
    }
  });

  /*
  it("everyone should be able to send ether to the wallet", async () => {
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
  */
});
