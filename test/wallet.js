const Wallet = artifacts.require("Wallet");
const truffleAssert = require('truffle-assertions');

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

const assertPayable = (err) => {
  if (web3.version.api.startsWith("1")) {
    assert.equal('revert', Object.values(err.results)[0].error);
  } else {
    assert.ok(err && err.message && err.message.includes('payable'));
  }
};


contract('Wallet', async accounts => {

  const owner = accounts[0];
  const user1 = accounts[1];
  const user2 = accounts[2];

  const val1  = web3.toWei(1.5, 'ether');
  const val2  = web3.toWei(4,   'ether');
  const val3  = web3.toWei(6,   'ether');
  const valBN = web3.toBigNumber(val1).add(web3.toBigNumber(val2)).add(web3.toBigNumber(val3));

  before('checking consts', async () => {
      assert(typeof owner == 'string', 'owner should be string');
      assert(typeof user1 == 'string', 'user1 should be string');
      assert(typeof user2 == 'string', 'user2 should be string');
      assert(typeof val1  == 'string', 'val1  should be string');
      assert(typeof val2  == 'string', 'val2  should be string');
      assert(typeof val3  == 'string', 'val2  should be string');
      assert(valBN instanceof web3.BigNumber, 'valBN should be big number');
  });

  before('setup contract for the test', async () => {
    instance = await Wallet.new();
  });

  it('should create empty wallet', async () => {
    const balance = await web3.eth.getBalance(instance.address);
    assert.equal(balance.toString(10), web3.toBigNumber(0).toString(10));
  });

  it('should accept ether from everyone', async () => {
    await web3.eth.sendTransaction({ from: owner, value: val1, to: instance.address });
    await web3.eth.sendTransaction({ from: user1, value: val2, to: instance.address });
    await web3.eth.sendTransaction({ from: user2, value: val3, to: instance.address });

    const balance = await web3.eth.getBalance(instance.address);
    assert.equal(balance.toString(10), valBN.toString(10));
  });

  it("only owner can call getBalance", async () => {
    const balance = await instance.getBalance.call({
      from: owner
    });
    assert.equal(balance.toString(10), valBN.toString(10));
    try {
      const balance = await instance.getBalance.call({
        from: user1
      });
      assert(false);
    } catch (err) {
      assertRevert(err);
    }
  });

  it("only owner can send ether", async () => {
    const userBalanceBefore = await web3.eth.getBalance(user2);
    await instance.sendEther(user2, web3.toBigNumber(val1), { from: owner });
    const userBalanceAfter = await web3.eth.getBalance(user2);
    const userBalanceDelta = userBalanceAfter - userBalanceBefore;
    assert.equal(userBalanceDelta, val1);

    try {
      await instance.sendEther(user2, web3.toBigNumber(val1), { from: user1 });
      assert(false);
    } catch (err) {
      assertRevert(err);
    }

  });

  it("should not allow sendEther to be payable", async () => {
    const contractBalanceBefore = await web3.eth.getBalance(instance.address);
    try {
      await instance.sendEther(owner, web3.toBigNumber(val1), { from: owner, value: val1 });
      assert(false);
    } catch (err) {
      assertPayable(err);
    }
    const contractBalanceAfter = await web3.eth.getBalance(instance.address);
    const contractBalanceDelta = contractBalanceBefore - contractBalanceAfter;
    assert.equal(contractBalanceDelta, web3.toBigNumber(0).toString(10));
  });

  it("should send ether from the contract when calling sendEther", async() => {
    const contractBalanceBefore = await web3.eth.getBalance(instance.address);
    const walletBalanceBefore = await instance.getBalance.call({ from: owner });

    await instance.sendEther(user2, web3.toBigNumber(val2), { from: owner });

    const contractBalanceAfter = await web3.eth.getBalance(instance.address);
    const walletBalanceAfter = await instance.getBalance.call({ from: owner });

    const contractBalanceDelta = contractBalanceBefore - walletBalanceAfter;
    const walletBalanceDelta = walletBalanceBefore - walletBalanceAfter;

    assert.equal(contractBalanceDelta, val2);
    assert.equal(walletBalanceDelta, val2);
  });

  it ("should send event with the sender and the value when getting ether", async () => {
    await web3.eth.sendTransaction({ from: owner, value: val3, to: instance.address });

    await instance.GotEther({}, { fromBlock: 'latest', toBlock: 'latest' })
    .get((err, txReceipt) => {
      assert.equal(err, undefined);
      assert.equal(txReceipt[0].event, "GotEther");
      const args = txReceipt[0].args;
      assert.equal(args.from, owner);
      assert.equal(args.value, val3);
    });
  });

    /*,
        await instance.OwnerTouched({}, { fromBlock: 'latest', toBlock: 'latest'})
    .get((error, txReceipt) => {
        assert.equal(txReceipt[0].event, "OwnerTouched");
    });

    //await web3.eth.sendTransaction({ from: owner, value: val3, to: instance.address },
      async (err, txHash) => {
        await web3.eth.getTransactionReceipt(txHash, (err, txReceipt) => {
          if (err) { console.log(err) }
          else { console.log(txReceipt) };
          //truffleAssert.eventEmitted(txReceipt, 'GotEther', (ev) => {
          //  return true; // ev.param1 === user2; // && ev.param2 === ev.param3;
          //});
        });
      });
      */

    /*
    console.log(tx);
    await web3.eth.getTransactionReceipt(tx, (err, txReceipt) => {
           if (err) {
             console.log(err)
           } else {
             console.log(txReceipt.logs[0])
           };
         });
    */

});
