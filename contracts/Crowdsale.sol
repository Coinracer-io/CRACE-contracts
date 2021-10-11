// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Crowdsale is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
	using SafeERC20 for IERC20;

	uint256 constant fundingGoal = 805 * (10**18);
	/* how much has been raised by crowdale (in BNB) */
	uint256 public amountRaised;
	/* how much has been raised by crowdale (in CRACE) */
	uint256 public amountRaisedCRACE;

	/* the start & end date of the crowdsale */
	uint256 public start;
	uint256 public deadline;
	uint256 public publishDate;

	/* there are different prices in different time intervals */
	uint256 constant price = 23238;

	/* the address of the token contract */
	IERC20 private tokenReward;
	/* the balances (in BNB) of all investors */
	mapping(address => uint256) public balanceOf;
	/* the balances (in CRACE) of all investors */
	mapping(address => uint256) public balanceOfCRACE;
	/* indicates if the crowdsale has been closed already */
	mapping(address => bool) public whitelist;
	bool public saleClosed = false;
	/* notifying transfers and the success of the crowdsale*/
	event GoalReached(address beneficiary, uint256 amountRaised);
	event FundTransfer(address backer, uint256 amount, bool isContribution, uint256 amountRaised);

    /*  initialization, set the token address */
    constructor(IERC20 _token, uint256 _start, uint256 _dead, uint256 _publish) {
        tokenReward = _token;
		start = _start;
		deadline = _dead;
		publishDate = _publish;
    }

	modifier onlyWhitelisted() {
        require(whitelist[_msgSender()] == true, "Caller is not whitelisted");
        _;
    }


    /* invest by sending BNB to the contract. */
    receive () external payable {
		if(msg.sender != owner()) //do not trigger investment if the multisig wallet is returning the funds
        	invest();
		else revert();
    }

	function updateDeadline(uint256 _dead, uint256 _publish) external onlyOwner {
		deadline = _dead;
		publishDate = _publish;
	}

	function checkFunds(address addr) external view returns (uint256) {
		return balanceOf[addr];
	}

	function checkCRACEFunds(address addr) external view returns (uint256) {
		return balanceOfCRACE[addr];
	}

	function getBNBBalance() external view returns (uint256) {
		return address(this).balance;
	}

	function isWhitelisted(address addr) external view returns (bool) {
		return whitelist[addr];
	}

	function addWhitelisted(address addr) external onlyOwner {
		whitelist[addr] = true;
	}

	function removeWhitelisted(address addr) external onlyOwner {
		whitelist[addr] = false;
	}

    /* make an investment
    *  only callable if the crowdsale started and hasn't been closed already and the maxGoal wasn't reached yet.
    *  the current token price is looked up and the corresponding number of tokens is transfered to the receiver.
    *  the sent value is directly forwarded to a safe multisig wallet.
    *  this method allows to purchase tokens in behalf of another address.*/
    function invest() public onlyWhitelisted payable {
    	uint256 amount = msg.value;
		require(saleClosed == false && block.timestamp >= start && block.timestamp < deadline, "sale-closed");
		require(msg.value >= 10**17, "less than 0.1 BNB");

		balanceOf[msg.sender] = balanceOf[msg.sender].add(amount);

		require(balanceOf[msg.sender] <= 5 * 10**18, "more than 5 BNB");

		amountRaised = amountRaised.add(amount);

		balanceOfCRACE[msg.sender] = balanceOfCRACE[msg.sender].add(amount.mul(price));
		amountRaisedCRACE = amountRaisedCRACE.add(amount.mul(price));

		if (amountRaised >= fundingGoal) {
			saleClosed = true;
			emit GoalReached(msg.sender, amountRaised);
		}
		
        emit FundTransfer(msg.sender, amount, true, amountRaised);
    }

    modifier afterClosed() {
        require(block.timestamp >= publishDate, "sale-in-progress");
        _;
    }

	function getCRACE() external afterClosed nonReentrant {
		require(balanceOfCRACE[msg.sender] > 0, "non-contribution");
		uint256 amount = balanceOfCRACE[msg.sender];
		uint256 balance = tokenReward.balanceOf(address(this));
		require(balance >= amount, "lack of funds");
		balanceOfCRACE[msg.sender] = 0;
		tokenReward.transfer(msg.sender, amount);
	}

	function withdrawBNB() external onlyOwner {
		uint256 balance = address(this).balance;
		require(balance > 0, "zero-balance");
		address payable payableOwner = payable(owner());
		payableOwner.transfer(balance);
	}

	function withdrawCRACE() external onlyOwner {
		uint256 balance = tokenReward.balanceOf(address(this));
		require(balance > 0, "zero-CRACE-balance");
		tokenReward.transfer(owner(), balance);
	}
}