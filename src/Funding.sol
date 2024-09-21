// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Fund {
    error Fund__InvalidAddress();
    error Fund__DonationMustBeAboveZero();
    error Fund__DonationEnded();
    error Fund__NotAuthorized();
    error Fund__TargetMet();
    error Fund__AmountLargerThanRemainingGoal();
    error Fund__CannotWithdrawTargetNotMet();
    error Fund__TransferFailed();
    error Fund__NoBalanceToRefund();
    error Fund__CannotRefundBeforeFundingEnds();
    error Fund__RefundFailed();

    event Received(address sender, uint256 amount, string message);
    event FundingEnded(uint256 fundingGoal, uint256 deadline, string message);
    event Refunded(address user, uint256 amount);

    uint256 public immutable i_fundingGoal;
    uint256 public immutable i_deadline;
    address payable public owner;
    uint256 public donation;

    mapping(address => uint256) public balances;

    constructor(uint256 _fundingGoal, uint256 _deadline) {
        i_fundingGoal = _fundingGoal;
        owner = payable(msg.sender);
        i_deadline = block.timestamp + _deadline;
    }

    ///////////////////////////////////
    /////////////Modifiers////////////
    /////////////////////////////////

    modifier onlyOwner() {
        require(owner == msg.sender, Fund__NotAuthorized());
        _;
    }

    modifier deadlineMet() {
        if (block.timestamp >= i_deadline) {
            revert Fund__DonationEnded();
        }
        _;
    }

    modifier targetMet() {
        if (donation == i_fundingGoal) {
            revert Fund__TargetMet();
        }
        _;
    }

    function donate() public payable deadlineMet targetMet {
        require(msg.value > (i_fundingGoal - donation), Fund__AmountLargerThanRemainingGoal());
        require(msg.sender != address(0), Fund__InvalidAddress());
        require(msg.value > 0, Fund__DonationMustBeAboveZero());

        // Track the donation
        balances[msg.sender] += msg.value;
        donation += msg.value; // Update total donation amount

        emit Received(msg.sender, msg.value, "Donation Received");

        // End funding if the goal is met
        if ((donation == i_fundingGoal) || (i_deadline == block.timestamp)) {
            endFunding();
        }
    }


    function endFunding() internal {
        emit FundingEnded(i_fundingGoal, i_deadline, "Funding Target Met");
    }

    // WITHDRAW
    function withdraw() external onlyOwner {
        require(donation >= i_fundingGoal || block.timestamp >= i_deadline, Fund__CannotWithdrawTargetNotMet());
        // Owner can withdraw the funds
        (bool success,) = owner.call{value: address(this).balance}("");
        require(success, Fund__TransferFailed());
    }

    // REFUND
    function refund() public {
        uint256 donatedAmount = balances[msg.sender];
        require(donatedAmount > 0, Fund__NoBalanceToRefund());
        require(block.timestamp >= i_deadline, Fund__CannotRefundBeforeFundingEnds());

        balances[msg.sender] = 0; // Set their balance to 0
        donation -= donatedAmount; // Decrease the total donation amount

        // Send back the amount
        (bool success,) = msg.sender.call{value: donatedAmount}("");
        require(success, Fund__RefundFailed());

        emit Refunded(msg.sender, donatedAmount);
    }

    /////////////////////////////////////////
    /////////////Getter Function////////////
    ///////////////////////////////////////

    function getCurrentTotalDonation() public view returns (uint256) {
        return donation;
    }

    function getRemainingGoal() public view returns (uint256) {
        return i_fundingGoal - donation;
    }

    function getRemainingTime() public view returns (uint256) {
        if (i_deadline <= block.timestamp) {
            return 0;
        } else {
            return (i_deadline - block.timestamp);
        }
    }

    /////////////////////////////////////////////
    /////////////Receive and Fallback////////////
    ////////////////////////////////////////////

    receive() external payable {
        donate();
    }

    fallback() external payable {
        donate();
    }
}
