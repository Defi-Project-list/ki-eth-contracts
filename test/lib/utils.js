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

module.exports = {
  sleep,
  getLatestBlockTimestamp
}

