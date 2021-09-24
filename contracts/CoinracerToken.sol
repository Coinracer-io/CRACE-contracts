// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract CoinracerToken is ERC20 {
  uint private constant _totalSupply = 10**8 * 10**18;

  constructor() ERC20("Coinracer", "CRACE"){
    // allocate all the found to the contract
    _mint(msg.sender, _totalSupply);  /// == address 0
  }
}
