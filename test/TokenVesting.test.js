const CoinracerToken = artifacts.require('CoinracerToken');
const TokenVesting = artifacts.require('TokenVesting');

const truffleAssert = require('truffle-assertions');

const { duration, increaseTimeTo } = require('./utils');

const { BN } = web3.utils;

contract('TokenVesting', (accounts) => {
  const amount = new BN(1000000);
  const initalAmount = new BN(500);
  const linearPart = amount.sub(initalAmount);
  const owner = accounts[1];
  const beneficiary = accounts[0];
  const tokenDeployer = accounts[2];

  beforeEach(async function () {
    this.token = await CoinracerToken.new({ from: tokenDeployer });

    this.t0 =
      (await web3.eth.getBlock('latest')).timestamp + 2;
    this.t1 =
      (await web3.eth.getBlock('latest')).timestamp + duration.minutes(2); // +2 minute so it starts after contract instantiation

    this.duration = duration.years(2);

    this.vesting = await TokenVesting.new(
      beneficiary,
      this.t0,
      this.t1,
      initalAmount,
      this.duration,
      owner,
      { from: owner }
    );

    // transfer tokens to vesting contract
    await this.token.transfer(this.vesting.address, amount, {
      from: tokenDeployer,
    });
  });

  it('cannot be released before t0', async function () {
    await truffleAssert.reverts(this.vesting.release(this.token.address));
  });

  it('can be released after t0', async function () {
    await increaseTimeTo(this.t0 + duration.minutes(1));
    const result = await this.vesting.release(this.token.address);

    truffleAssert.eventEmitted(result, 'TokensReleased');
  });


  it('should release proper amount between t0 and t1', async function () {
    await increaseTimeTo(this.t0 + duration.minutes(1));
     await this.vesting.release(this.token.address);
    const balance = await this.token.balanceOf(beneficiary);
    assert.ok(balance.eq(initalAmount));
  });

  it('can be released after t1', async function () {
    await increaseTimeTo(this.t1 + duration.weeks(1));
    const result = await this.vesting.release(this.token.address);

    truffleAssert.eventEmitted(result, 'TokensReleased');
  });


  it('should release proper amount after t1', async function () {
    await increaseTimeTo(this.t1 + duration.weeks(1));

    const { receipt } = await this.vesting.release(this.token.address);

    const releaseTime = (await web3.eth.getBlock(receipt.blockNumber))
      .timestamp;

    const balance = await this.token.balanceOf(beneficiary);

    const elapsed = new BN(releaseTime - this.t1);

    const durationBN = new BN(this.duration);

    assert.ok(balance.eq(initalAmount.add(linearPart.mul(elapsed).div(durationBN))));
    assert.ok(!balance.eq(linearPart.mul(elapsed).div(durationBN)));
  });

  it('should linearly release tokens during vesting period', async function () {
    const vestingPeriod = this.duration;
    const checkpoints = 4;

    for (let i = 1; i <= checkpoints; i++) {
      const now = this.t1 + i * (vestingPeriod / checkpoints);
      await increaseTimeTo(now);

      await this.vesting.release(this.token.address);
      const balance = await this.token.balanceOf(beneficiary);
      const expectedVesting = initalAmount.add(linearPart
        .mul(new BN(now - this.t1))
        .div(new BN(this.duration)));

      assert.ok(balance.eq(expectedVesting));
    }
  });

  it('should have released all after end', async function () {
    await increaseTimeTo(this.t1 + this.duration);
    await this.vesting.release(this.token.address);
    const balance = await this.token.balanceOf(beneficiary);
    assert.ok(balance.eq(amount));
  });

});
