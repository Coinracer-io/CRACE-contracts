const CoinracerToken = artifacts.require('CoinracerToken');

module.exports = async function (deployer, network, accounts) {
  await deployer.deploy(CoinracerToken);
  const tokenInstance = await CoinracerToken.deployed();
  // const tokenInstance = await CoinracerToken.at(process.env.CRACE.trim());
  

};
