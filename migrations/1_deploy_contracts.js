const CoinracerToken = artifacts.require('CoinracerToken');
const TokenVestingFactory = artifacts.require('TokenVestingFactory');

const distributions = require('../configs/distributions.json');

const BN = require('bn.js');

const DECIMALS = new BN(10).pow(new BN(18));

function getParamFromTxEvent(
  transaction,
  paramName,
  contractFactory,
  eventName
) {
  if (typeof transaction !== 'object' || transaction === null)
    throw new Error('Not an object');
  let logs = transaction.logs;
  if (eventName != null) {
    logs = logs.filter((l) => l.event === eventName);
  }
  if (logs.length !== 1) throw new Error('too many logs found!');

  let param = logs[0].args[paramName];
  if (contractFactory != null) {
    let contract = contractFactory.at(param);
    if (typeof transaction === 'object' || transaction === null)
      throw new Error(`getting ${paramName} failed for ${param}`);
    return contract;
  } else {
    return param;
  }
}

async function createVestingContract(
  tokenInstance,
  factoryInstance,
  name,
  address, 
  t0, 
  t1, 
  initialPercent, 
  duration, 
  tokens
) {
  const tokenAmount = new BN(tokens).mul(DECIMALS);
  const initialAmount = tokenAmount.mul(new BN(initialPercent)).div(new BN(100));

  console.log(
    `Creating vesting contract for '${name}' @ ${address}`
  );
  console.log(
    `Contracts parameters : t0:${t0}, t1:${t1}, duration:${duration}`
  )

  const result = await factoryInstance.create(
    address,
    t0,
    t1,
    initialAmount,
    duration
  );

  const contractAddress = getParamFromTxEvent(result, 'instantiation');

  console.log(
    `Transferring ${tokenAmount
      .div(DECIMALS)
      .toString()} CRACE tokens to '${name}' @ ${contractAddress}`
  );
  await tokenInstance.transfer(contractAddress, tokenAmount);
};

module.exports = async function (deployer, network, accounts) {
  await deployer.deploy(CoinracerToken);
  const tokenInstance = await CoinracerToken.deployed();
  // const tokenInstance = await CoinracerToken.at(process.env.CRACE.trim());
  
  await deployer.deploy(TokenVestingFactory);
  const factoryInstance = await TokenVestingFactory.deployed();

  // create a vesting contract for each distribution
  
  for (key in distributions) {
    const params = distributions[key];
    console.log(`${key} distribution started`);

    for (const{name, address, amount} of params.beneficiaries) {
      await createVestingContract(
        tokenInstance,
        factoryInstance, 
        name, 
        address, 
        params.t0, 
        params.t1,
        params.day1Percent, 
        params.duration, 
        amount
      );
    }
  }
};
