const fs = require('fs');

const CoinracerToken = artifacts.require('CoinracerToken');
const TokenVestingFactory = artifacts.require('TokenVestingFactory');
// const Crowdsale = artifacts.require("Crowdsale");
var Staking = artifacts.require('Staking');

const distributions = require("../configs/distributions.json");
// const whitelist = require("../configs/whitelist.json");
const contractAddresses = require("../configs/contracts.json");
const stakingConfig = require("../configs/staking.json");

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
  try {

    let dataParse = {};

    let tokenInstance = null;
    if (!contractAddresses.CoinracerToken) {
      await deployer.deploy(CoinracerToken);
      tokenInstance = await CoinracerToken.deployed();
      // const tokenInstance = await CoinracerToken.at(process.env.CRACE.trim());  
      dataParse['CoinracerToken'] = CoinracerToken.address;
    }
    else {
      tokenInstance = await CoinracerToken.at(contractAddresses.CoinracerToken);
      dataParse['CoinracerToken'] = contractAddresses.CoinracerToken;
    }
    
    if (!contractAddresses.TokenVestingFactory) {
      await deployer.deploy(TokenVestingFactory);
      const factoryInstance = await TokenVestingFactory.deployed();
      dataParse['TokenVestingFactory'] = TokenVestingFactory.address;

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
    }
    else {
      dataParse['TokenVestingFactory'] = contractAddresses.TokenVestingFactory;
    }

    // if (!contractAddresses.Crowdsale) {
    //   const startOfICO = Math.floor(Date.UTC(2021, 9, 4, 0, 0, 0) / 1000); // 04/10/2021
    //   const endOfICO = Math.floor(Date.UTC(2021, 9, 22, 0, 0, 0) / 1000);   //   22/10/2021
    //   const publishDate = Math.floor(Date.UTC(2021, 9, 23, 0, 0, 0) / 1000);    // 23/10/2021

    //   await deployer.deploy(Crowdsale, dataParse['CoinracerToken'], startOfICO, endOfICO, publishDate, {
    //     gas: 5000000
    //   });
    //   const crowdsaleInstance = await Crowdsale.deployed();
    //   dataParse['Crowdsale'] = Crowdsale.address;

    //   for (account in whitelist) {
    //     await crowdsaleInstance.addWhitelisted(account);
    //   }
    // }
    // else {
    //   dataParse["Crowdsale"] = contractAddresses.Crowdsale;
    // }

    if (!contractAddresses.Staking) {
      const currentBlock = await web3.eth.getBlockNumber();
      const startBlock = stakingConfig.staking_param.startBlock
          || web3.utils.toBN(currentBlock).add(web3.utils.toBN(stakingConfig.staking_param.delay));

      await deployer.deploy(Staking, dataParse['CoinracerToken'], web3.utils.toBN(stakingConfig.staking_param.rewardPerBlock), startBlock, {
          gas: 3000000
      });
      const stakingInstance = await Staking.deployed();
      dataParse['Staking'] = Staking.address;

      if (stakingConfig.staking_param.fund) {
          const tokenInstance = await CoinracerToken.at(dataParse['CoinracerToken']);
          await tokenInstance.approve(Staking.address, web3.utils.toBN(stakingConfig.staking_param.fund));
          await stakingInstance.fund(web3.utils.toBN(stakingConfig.staking_param.fund));
      }

      for (let i = 0; i < stakingConfig.staking_param.token.length; i ++) {
        const token = stakingConfig.staking_param.token[i];
        if (token.address) {
          await stakingInstance.add(
              token.allocPoint,
              token.address,
              false
          );
        }
      }
    }
    else {
        dataParse['Staking'] = contractAddresses.Staking;
    }

    const updatedData = JSON.stringify(dataParse);
    await fs.promises.writeFile("./configs/contracts.json", updatedData);
  } catch (error) {
    console.log(error);
  }
};
