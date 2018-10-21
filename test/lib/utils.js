'use strict';

const sleep = (milliseconds) => {
  return new Promise((r, j) => setTimeout(() => { r() }, milliseconds));
};

const getLatestBlockTimestamp = async (timeUnitInSeconds=1) => {
  const timestamp = await new Promise(
    (r, j) => web3.eth.getBlock('latest', (err, block) => r(block.timestamp)));
  return Math.floor(timestamp/timeUnitInSeconds);
};

const mine = async (account) => {
  web3.eth.sendTransaction({ value: 0, from: account, to: account});
};

const isBackupActivated = async (wallet) => {
    return (await wallet.getBackupState()).eq(await wallet.BACKUP_STATE_ACTIVATED());
}

module.exports = {
  sleep,
  getLatestBlockTimestamp,
  mine,
  isBackupActivated
}
