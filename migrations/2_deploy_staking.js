var fs = require('fs');

var Staking = artifacts.require("../contracts/Staking.sol");
var CoinracerToken = artifacts.require("../contracts/CoinracerToken.sol");

const contractAddresses = require("../configs/contracts.json");
const stakingConfig = require("../configs/staking.json");

module.exports = async function(deployer) {
    try {
        let dataParse = contractAddresses;

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
