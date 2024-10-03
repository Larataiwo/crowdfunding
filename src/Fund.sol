// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {PriceConverter} from "./PriceConverter.sol";

contract Fund {
    using PriceConverter for uint256;

    error Fund__InvalidAddress();
    error Fund__DonationMustBeAboveZero();
    error Fund__DonationNotEnded();
    error Fund__NotAuthorized();
    error Fund__TargetNotMet();
    error Fund__AmountLargerThanRemainingGoal();
    error Fund__NoBalanceToRefund();

    event Received(address sender, uint256 amount, string message);
    event FundingEnded(uint256 fundingGoal, uint256 deadline, string message);
    event Refunded(address user, uint256 amount);

    uint256 private constant FUNDING_GOAL = 5000 * 10 ** 18;
    uint256 private constant MINIMUM_FEE = 5 * 10 ** 18;
    uint256 private immutable i_deadline;
    address private immutable i_owner;
    uint256 private donationBalance;
    AggregatorV3Interface public s_priceFeed;

    mapping(address => uint256) private funder;
    address[] private fundersList;

    constructor(uint256 _deadline, address _priceFeed) {
        s_priceFeed = AggregatorV3Interface(_priceFeed);
        i_owner = msg.sender;
        i_deadline = block.timestamp + _deadline;
    }

    ///////////////////////////////////
    /////////////Modifiers////////////
    /////////////////////////////////

    modifier onlyOwner() {
        require(i_owner == msg.sender, Fund__NotAuthorized());
        _;
    }

    modifier deadlineMet() {
        if (block.timestamp <= i_deadline) {
            revert Fund__DonationNotEnded();
        }
        _;
    }

    modifier targetMet() {
        if (donationBalance < FUNDING_GOAL) {
            revert Fund__TargetNotMet();
        }
        _;
    }

    receive() external payable {
        donate();
    }

    fallback() external payable {
        donate();
    }

    function donate() public payable {
        //require(msg.value <= (FUNDING_GOAL - donationBalance), Fund__AmountLargerThanRemainingGoal());
        require(msg.sender != address(0), Fund__InvalidAddress());
        require(msg.value.getConversionRate(s_priceFeed) >= MINIMUM_FEE, Fund__DonationMustBeAboveZero());

        // Track the donationBalance
        funder[msg.sender] += msg.value;
        fundersList.push(msg.sender);

        donationBalance += msg.value; // Update total donationBalance amount

        emit Received(msg.sender, msg.value, "Donation Received");
    }

    function endFunding() internal onlyOwner {
        if ((donationBalance == FUNDING_GOAL) || (i_deadline == block.timestamp)) {
            emit FundingEnded(FUNDING_GOAL, i_deadline - block.timestamp, "Funding Target Met");
        }
    }

    // WITHDRAW
    function withdraw() external onlyOwner {
        require(donationBalance >= FUNDING_GOAL || block.timestamp >= i_deadline, Fund__TargetNotMet());
        // Owner can withdraw the funds
        (bool success,) = i_owner.call{value: address(this).balance}("");
        require(success);
    }

    function withdrawal() public onlyOwner {
        for (uint256 funderIndex = 0; funderIndex < fundersList.length; funderIndex++) {
            address funders = fundersList[funderIndex];
            funder[funders] = 0;
        }
        fundersList = new address[](0);

        (bool success,) = i_owner.call{value: address(this).balance}("");
        require(success);
    }

    // REFUND
    function refund() public deadlineMet targetMet {
        uint256 donatedAmount = funder[msg.sender];
        require(msg.sender != address(0), Fund__InvalidAddress());
        require(donatedAmount > 0, Fund__NoBalanceToRefund());
        require(donationBalance > FUNDING_GOAL, Fund__TargetNotMet());

        funder[msg.sender] = 0; // Set their balance to 0

        uint256 excess = (donationBalance - FUNDING_GOAL);
        uint256 balanceLeft = donatedAmount - excess;
        donationBalance -= balanceLeft; // Decrease the total donationBalance amount

        // Send back the amount
        (bool success,) = msg.sender.call{value: balanceLeft}("");
        require(success);

        emit Refunded(msg.sender, balanceLeft);
    }

    /////////////Getter Function////////////

    function getCurrentTotalDonation() public view returns (uint256) {
        return donationBalance;
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }


    function getOwnerBalance() public view returns (uint256) {
        return i_owner.balance;
    }

    function getRemainingGoal() public view returns (uint256) {
        if (donationBalance >= FUNDING_GOAL) {
            return 0;
        } else {
            return FUNDING_GOAL - donationBalance;
        }
    }

    function getRemainingTime() public view returns (uint256) {
        if (i_deadline <= block.timestamp) {
            return 0;
        } else {
            return (i_deadline - block.timestamp);
        }
    }

    function getOwner() public view returns (address) {
        return i_owner;
    }

    function getPriceFeed() public returns (AggregatorV3Interface) {
        return s_priceFeed;
    }
}
