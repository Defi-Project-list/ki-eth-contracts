'use strict';

const Backup = {}; //artifacts.require("Backup");

const getBalanceInWei = async (account) => {
  let balance = 0;
  try {
    balance = await web3.eth.getBalance(account);
  }
  catch(e) {
    assert(false, e.message);
  }
  return balance;
}

const toEtherString = async (valueInWei) => {
  const valueInEth = await web3.fromWei(valueInWei, "ether");
  return `${valueInEth} ETH`;
}

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

describe.skip('old backup', () => {
contract('Backup', async accounts => {
  let instance = null;
  let owner = accounts[0];
  let user1 = accounts[1];
  let ownerBalance = new web3.BigNumber(0);
  let ownerPrevBalance = new web3.BigNumber(0);
  let user1Balance = new web3.BigNumber(0);
  let gasPrice;

  const sendOptions = (account) => ({ from: account, gasPrice: gasPrice });

  const updateBalance = async () => {
    ownerPrevBalance = ownerBalance;
    ownerBalance = await getBalanceInWei(owner);
    mlog.log(`owner balance: \t${await toEtherString(ownerBalance)}`);
    mlog.log(`${typeof ownerBalance}`);
    const tax = ownerPrevBalance.minus(ownerBalance);
    if (tax > 0) {
      mlog.log(`owner tr.tax: \t${await toEtherString(tax)}`);
      mlog.log(`owner gas used: \t${/*Math.floor(...)*/(tax / gasPrice)}`);
    }
  }

  before('', async () => {
    gasPrice = web3.eth.gasPrice;
    mlog.log(`gasPrice: ${await toEtherString(gasPrice)}`);
  });

  beforeEach("get up-to-date balance", async () => {
    await updateBalance();
  });

  after("get up-to-date balance", async () => {
    await updateBalance();
  });

  it('backup contract creation', async () => {
    instance = await Backup.new(sendOptions(owner));
  });

  it('setBackup', async () => {
    let res = await instance.setBackup(user1, 200, sendOptions(owner));
    //mlog.log(Object.keys(res.receipt));
    mlog.log((res.receipt.gasUsed));
  });

  it('touch', async () => {
    let res = await instance.touch({
      from: owner,
      gasPrice: gasPrice
    });
    mlog.log((res.receipt.gasUsed));
  });

  it("second touch", async () => {
    let res = await instance.touch(sendOptions(owner));
    mlog.log(res.receipt.gasUsed);
  });

});
});
