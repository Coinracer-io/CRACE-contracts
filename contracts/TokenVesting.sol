// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TokenVesting
 * @dev A token holder contract that can release its token balance gradually like a
 * typical vesting scheme, with a cliff and vesting period. Optionally revocable by the
 * owner.
 */
contract TokenVesting is Ownable {
  // The vesting schedule is time-based
  // solhint-disable not-rely-on-time

  using SafeERC20 for IERC20;

  event TokensReleased(address token, uint256 amount);

  // beneficiary of tokens after they are released
  address private beneficiary;
  // Durations and timestamps are expressed in UNIX time, the same units as block.timestamp.
  uint256 private t0;
  uint256 private t1;
  uint256 private duration; //duration of the release after t1
  uint256 private initialAmount;

  mapping(address => uint256) private released;

  /**
   * @dev Creates a vesting contract that vests its balance of any ERC20 token to the
   * beneficiary, gradually in a linear fashion until start + duration. By then all
   * of the balance will have vested.
   * @param _beneficiary address of the beneficiary to whom vested tokens are transferred
   * @param _t0 the time (as Unix time) at which point initial release start
   * @param _t1 the time (as Unix time) at which point linear release vesting starts
   * @param _duration duration in seconds of the period in which the tokens will vest
   */
  constructor(
    address _beneficiary,
    uint256 _t0,
    uint256 _t1,
    uint256 _initialAmount, // initial amount delivered
    uint256 _duration,
    address _owner
  ) {
    require(
      _beneficiary != address(0),
      'TokenVesting: beneficiary is the zero address'
    );
    // solhint-disable-next-line max-line-length
    require(
      _t0 <= _t1,
      'TokenVesting: t0 is bigger than t1'
    );
    require(_duration > 0, 'TokenVesting: duration is 0');
    // solhint-disable-next-line max-line-length
    require(
      _t1 +_duration > block.timestamp,
      'TokenVesting: final time is before current time'
    );

    initialAmount = _initialAmount;
    beneficiary = _beneficiary;
    duration = _duration;
    t0 = _t0;
    t1 = _t1;

    // ownable call for ownership transfer
    transferOwnership(_owner);
  }

  /**
   * @return the beneficiary of the tokens.
   */
  function getBeneficiary() external view returns (address) {
    return beneficiary;
  }

  /**
   * @return the initial amount claimable at t0;
   */
  function getInitialAmount() external view returns (uint256) {
    return initialAmount;
  }

  /**
   * @return the cliff time of the token vesting.
   */
  function getT0() external view returns (uint256) {
    return t0;
  }

  /**
   * @return the start time of the token vesting.
   */
  function getT1() external view returns (uint256) {
    return t1;
  }

  /**
   * @return the duration of the token vesting.
   */
  function getDuration() external view returns (uint256) {
    return duration;
  }

  /**
   * @return the amount of the token released.
   */
  function getReleased(address token) external view returns (uint256) {
    return released[token];
  }


  /**
   * @return the amount of the token vested.
   */
  function getVestedAmount(IERC20 token) external view returns (uint256) {
    return _vestedAmount(token);
  }

  /**
   * @notice Transfers vested tokens to beneficiary.
   * @param token ERC20 token which is being vested
   */
  function release(IERC20 token) public {
    uint256 unreleased = _releasableAmount(token);
    require(unreleased > 0, 'TokenVesting: no tokens are due');

    released[address(token)] = released[address(token)] + unreleased;

    token.safeTransfer(beneficiary, unreleased);

    emit TokensReleased(address(token), unreleased);
  }


  /**
   * @dev Calculates the amount that has already vested but hasn't been released yet.
   * @param token ERC20 token which is being vested
   */
  function _releasableAmount(IERC20 token) private view returns (uint256) {
    return _vestedAmount(token) - released[address(token)];
  }

  /**
   * @dev Calculates the amount that has already vested.
   * @param token ERC20 token which is being vested
   */
  function _vestedAmount(IERC20 token) private view returns (uint256) {
    uint256 currentBalance = token.balanceOf(address(this));
    uint256 totalBalance = currentBalance + released[address(token)];

    // before t0 nothing to vest
    if (block.timestamp < t0) {
        return 0;
    // between t0 and t1, inital amount to vest
    }else if (block.timestamp >= t0 && block.timestamp < t1) {
        return initialAmount;
    // after t1 + duration, total balance can be vested
    }else if (block.timestamp > t1 + duration) {
        return totalBalance;
    // linear part during t1 and t1 + duration
    }else{
        // implicit, totalBalance > initialAmount
        uint256 linearPart = totalBalance - initialAmount;
        // after t1, initialAmount + a proportion of linear part claimable
        return initialAmount + linearPart*(block.timestamp - t1)/duration;
    }
  }
}
