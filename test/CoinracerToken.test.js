const CoinracerToken = artifacts.require('CoinracerToken');
const BN = require('bn.js');

const deployToken = () => {
  return CoinracerToken.new();
};

contract('CoinracerToken', (accounts) => {
  let tokenInstance;

  before(async () => {
    tokenInstance = await deployToken();
    assert.ok(tokenInstance);
  });

  it('should put 100 million CoinracerToken in the first account', async () => {
    const balance = await tokenInstance.balanceOf.call(accounts[0]);
    assert(
      balance.valueOf().eq(new BN('100000000000000000000000000', 10)),
      "100000000 wasn't in the first account"
    );
  });

  it('should send coin correctly', () => {
    let crace = tokenInstance;

    // Get initial balances of first and second account.
    const account_one = accounts[0];
    const account_two = accounts[1];

    let account_one_starting_balance;
    let account_two_starting_balance;
    let account_one_ending_balance;
    let account_two_ending_balance;

    const amount = new BN('1000000000000000000', 10);

    return crace.balanceOf
      .call(account_one)
      .then((balance) => {
        account_one_starting_balance = balance;
        return crace.balanceOf.call(account_two);
      })
      .then((balance) => {
        account_two_starting_balance = balance;
        return crace.transfer(account_two, amount, { from: account_one });
      })
      .then(() => crace.balanceOf.call(account_one))
      .then((balance) => {
        account_one_ending_balance = balance;
        return crace.balanceOf.call(account_two);
      })
      .then((balance) => {
        account_two_ending_balance = balance;

        assert(
          account_one_ending_balance.eq(
            account_one_starting_balance.sub(amount)
          ),
          "Amount wasn't correctly taken from the sender"
        );
        assert(
          account_two_ending_balance.eq(
            account_two_starting_balance.add(amount)
          ),
          "Amount wasn't correctly sent to the receiver"
        );
      });
  });
});
