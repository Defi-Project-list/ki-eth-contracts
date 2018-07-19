'use strict';

const sleep = async (milliseconds) => {
  const timestamp = await new Promise(
    (r, j) => setTimeout(() => {
      r()
    }, milliseconds));
  return timestamp;
};

const getLatestBlockTimestamp = async () => {
  const timestamp = await new Promise(
    (r, j) => web3.eth.getBlock('latest', (err, block) => r(block.timestamp)));
  return timestamp;
};

const mine = async (account) => {
  web3.eth.sendTransaction({ value: 0, from: account, to: account});
};

module.exports = {
  sleep,
  getLatestBlockTimestamp,
  mine
}
