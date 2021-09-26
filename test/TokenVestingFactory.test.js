const CoinracerToken = artifacts.require('CoinracerToken');
const TokenVestingFactory = artifacts.require('TokenVestingFactory');

const truffleAssert = require('truffle-assertions');

const { duration, getParamFromTxEvent } = require('./utils');

contract('TokenVestingFactory', (accounts) => {
  const owner = accounts[1];
  const beneficiary = accounts[0];
  const tokenDeployer = accounts[2];

  before(async function () {
    this.token = await CoinracerToken.new({ from: tokenDeployer });
    this.factory = await TokenVestingFactory.new({ from: tokenDeployer });

    this.t0 =
      (await web3.eth.getBlock('latest')).timestamp;
    this.t1 =
      (await web3.eth.getBlock('latest')).timestamp + duration.minutes(2); // +2 minute so it starts after contract instantiation

    this.duration = duration.years(2);
  });

  it('creates a token vesting contract', async function () {
    const result = await this.factory.create(
      beneficiary,
      this.t0,
      this.t1,
      0,
      this.duration,
      { from: owner }
    );

    truffleAssert.eventEmitted(result, 'ContractInstantiation');
  });

  it('reverts when recreating contract with the same beneficiary', async function () {
    await truffleAssert.reverts(
      this.factory.create(
        beneficiary,
        this.t0,
        this.t1,
        0,
        this.duration,
        { from: owner }
      )
    );
  });

  it('allows msg.sender to find its contract address', async function () {
    const result = await this.factory.create(
      accounts[6],
      this.t0,
      this.t1,
      0,
      this.duration,
      { from: owner }
    );

    const address = getParamFromTxEvent(result, 'instantiation');

    const returnedAddress = await this.factory.getVestingAddress.call({
      from: accounts[6],
    });

    assert.ok(address === returnedAddress);
  });
});
