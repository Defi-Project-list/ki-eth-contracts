'use strict';

const sleep = async (milliseconds) => {
  const timestamp = await new Promise(
    (r, j) => setTimeout(() => {
      r()
    }, milliseconds));
  return timestamp;
};

const getLatestBlockTimestamp = async (timeUnitInSeconds=1) => {
  const timestamp = await new Promise(
    (r, j) => web3.eth.getBlock('latest', (err, block) => r(block.timestamp)));
  return Math.floor(timestamp/timeUnitInSeconds);
};

const mine = async (account) => {
  web3.eth.sendTransaction({ value: 0, from: account, to: account});
};

module.exports = {
  sleep,
  getLatestBlockTimestamp,
  mine
}
