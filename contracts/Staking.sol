// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Staking distributes the CRACE rewards based on staked CRACE to each user.

contract Staking is Ownable {
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many CRACE tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 timestamp;
        //
        // We do some fancy math here. Basically, any point in time, the amount of BEP20s
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accERC20PerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws CRACE tokens to a pool. Here's what happens:
        //   1. The pool's `accERC20PerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 bep20Token;             // Address of BEP20 token contract.
        uint256 allocPoint;         // How many allocation points assigned to this pool. BEP20s to distribute per block.
        uint256 lastRewardBlock;    // Last block number that BEP20s distribution occurs.
        uint256 accERC20PerShare;   // Accumulated BEP20s per share, times 1e36.
    }

    // Address of the CRACE Token contract.
    IERC20 public crace;
    // The total amount of CRACE that's paid out as reward.
    uint256 public paidOut = 0;
    // CRACE tokens rewarded per block.
    uint256 public rewardPerBlock;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes BEP20 tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;

    // The block number when staking starts.
    uint256 public startBlock;
    // The block number when staking ends.
    uint256 public endBlock;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(IERC20 _crace, uint256 _rewardPerBlock, uint256 _startBlock) {
        crace = _crace;
        rewardPerBlock = _rewardPerBlock;
        startBlock = _startBlock;
        endBlock = _startBlock;
    }

    // Number of staking pools
    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Fund the Staking, increase the end block
    function fund(uint256 _amount) external onlyOwner {
        require(block.number < endBlock, "fund: too late, the staking is closed");

        crace.transferFrom(address(msg.sender), address(this), _amount);
        endBlock += _amount / rewardPerBlock;
    }

    // Add a new BEP20 to the pool. Can only be called by the owner.
    // DO NOT add the same BEP20 token more than once. Rewards will be messed up if you do.
    function add(uint256 _allocPoint, IERC20 _bep20Token, bool _withUpdate) external onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint + _allocPoint;
        poolInfo.push(PoolInfo({
            bep20Token: _bep20Token,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accERC20PerShare: 0
        }));
    }

    // Update the given pool's BEP20 allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) external onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint - poolInfo[_pid].allocPoint + _allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    // View function to see deposited BEP20 for a user.
    function deposited(uint256 _pid, address _user) external view returns (uint256) {
        UserInfo storage user = userInfo[_pid][_user];
        return user.amount;
    }

    // View function to see pending BEP20s for a user.
    function pending(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accERC20PerShare = pool.accERC20PerShare;
        uint256 bep20Supply = pool.bep20Token.balanceOf(address(this));

        if (block.number > pool.lastRewardBlock && bep20Supply != 0) {
            uint256 lastBlock = block.number < endBlock ? block.number : endBlock;
            uint256 nrOfBlocks = lastBlock - pool.lastRewardBlock;
            uint256 erc20Reward = nrOfBlocks * rewardPerBlock * pool.allocPoint / totalAllocPoint;
            accERC20PerShare = accERC20PerShare + erc20Reward * 1e36 / bep20Supply;
        }

        return user.amount * accERC20PerShare / 1e36 - user.rewardDebt;
    }

    // View function for total reward the staking has yet to pay out.
    function totalPending() external view returns (uint256) {
        if (block.number <= startBlock) {
            return 0;
        }

        uint256 lastBlock = block.number < endBlock ? block.number : endBlock;
        return rewardPerBlock * (lastBlock - startBlock) - paidOut;
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        uint256 lastBlock = block.number < endBlock ? block.number : endBlock;

        if (lastBlock <= pool.lastRewardBlock) {
            return;
        }
        uint256 bep20Supply = pool.bep20Token.balanceOf(address(this));
        if (bep20Supply == 0) {
            pool.lastRewardBlock = lastBlock;
            return;
        }

        uint256 nrOfBlocks = lastBlock - pool.lastRewardBlock;
        uint256 erc20Reward = nrOfBlocks * rewardPerBlock * pool.allocPoint / totalAllocPoint;

        pool.accERC20PerShare = pool.accERC20PerShare + erc20Reward * 1e36 / bep20Supply;
        pool.lastRewardBlock = block.number;
    }

    // Deposit BEP20 tokens to Staking for BEP20 allocation.
    function deposit(uint256 _pid, uint256 _amount) external {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pendingAmount = user.amount * pool.accERC20PerShare / 1e36 - user.rewardDebt;
            craceTransfer(msg.sender, pendingAmount);
        }
        pool.bep20Token.safeTransferFrom(address(msg.sender), address(this), _amount);
        user.timestamp = block.timestamp;
        user.amount = user.amount + _amount;
        user.rewardDebt = user.amount * pool.accERC20PerShare / 1e36;
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw BEP20 tokens from Staking.
    function withdraw(uint256 _pid, uint256 _amount) external {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: can't withdraw more than deposit");
        require(block.timestamp - user.timestamp >= 7776000, "can't withdraw within 90 days");
        updatePool(_pid);
        uint256 pendingAmount = user.amount * pool.accERC20PerShare / 1e36 - user.rewardDebt;
        craceTransfer(msg.sender, pendingAmount);
        user.amount = user.amount - _amount;
        user.rewardDebt = user.amount * pool.accERC20PerShare / 1e36;
        pool.bep20Token.safeTransfer(address(msg.sender), _amount);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) external {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.bep20Token.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    // Transfer CRACE and update the required CRACE to payout all rewards
    function craceTransfer(address _to, uint256 _amount) internal {
        crace.transfer(_to, _amount);
        paidOut += _amount;
    }

    function withdrawFunds(address _token, address _to) external onlyOwner {
        require(block.number > endBlock, "staking is live");
        IERC20 token = IERC20(_token);
        uint256 balance = token.balanceOf(address(this));
        token.transfer(_to, balance);
    }
}
