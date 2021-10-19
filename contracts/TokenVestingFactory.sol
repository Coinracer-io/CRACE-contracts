// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.3;

import './TokenVesting.sol';

contract TokenVestingFactory {
  /*
   *  Events
   */
  event ContractInstantiation(address instantiation, address beneficiary);

  /*
   *  Storage
   */
  mapping(address => bool) public isInstantiation;
  mapping(address => address) public vestingAddress;

  /// @dev Returns address of vesting contract
  /// @return Returns address of vesting contract
  function getVestingAddress() external view returns (address) {
    return vestingAddress[msg.sender];
  }

  /*
   * Internal functions
   */
  /// @dev Registers contract in factory registry.
  /// @param instantiation Address of contract instantiation.
  function register(address instantiation, address beneficiary) internal {
    isInstantiation[instantiation] = true;
    vestingAddress[beneficiary] = instantiation;
    emit ContractInstantiation(instantiation, beneficiary);
  }

  /*
   * Public functions
   */
  /// @dev Allows verified creation of Token Vesting Contract
  /// Returns wallet address.
  function create(
    address _beneficiary,
    uint256 _t0,
    uint256 _t1,
    uint256 _initialAmount,
    uint256 _duration
  ) external returns (address contractAddress) {
    require(
      vestingAddress[_beneficiary] == address(0),
      'Beneficiary already has a vesting contract!'
    );

    contractAddress = address(
      new TokenVesting(
        _beneficiary,
        _t0,
        _t1,
        _initialAmount,
        _duration,
        msg.sender
      )
    );

    register(contractAddress, _beneficiary);
  }
}
