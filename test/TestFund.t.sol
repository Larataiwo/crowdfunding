// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Fund} from "../src/Fund.sol";
import {Deploy} from "../script/DeployFund.s.sol";
import {HelperConfig, CodeConstants} from "../script/HelperConfig.s.sol";
import {MockV3Aggregator} from "./mock/MockV3Aggregator.sol";

contract TestFunding is CodeConstants, Test {
    HelperConfig public helperConfig;
    Fund public fund;

    //uint256 private constant DEADLINE = 2 weeks;

    address owner;
    address Jack;
    address Peter;
    uint256 public initialFund = 1000 ether;

    function setUp() public {
        Deploy deployer = new Deploy();
        (fund, helperConfig) = deployer.deployFund();

        Jack = address(1);
        Peter = address(2);

        vm.deal(Jack, initialFund);
        vm.deal(Peter, initialFund);
    }

     function testPriceFeedSetCorrectly() public {
        address fundPriceFeed = address(fund.getPriceFeed());
        address chainIdPriceFeed = helperConfig.getConfigByChainId(block.chainid).priceFeed;
        assertEq(fundPriceFeed, chainIdPriceFeed);
    }

    function testDonate() public {
        vm.prank(Jack);
        fund.donate{value: 0.001 ether}();
        fund.getCurrentTotalDonation();

        // vm.prank(Peter);
        // fund.donate{value: 1000 ether}();
        // fund.getCurrentTotalDonation();
        fund.getRemainingGoal();
        fund.getOwner();
    }

    function testRefund() public {
        vm.prank(Jack);
        fund.donate{value: 50 ether}();
        fund.getCurrentTotalDonation();

        vm.prank(Peter);
        fund.donate{value: 1000 ether}();
        fund.getCurrentTotalDonation();

        vm.warp(block.timestamp + 3 weeks);
        vm.prank(Peter);
        fund.refund();
        fund.getContractBalance();
        fund.getRemainingGoal();
        fund.getCurrentTotalDonation();
    }

    function testEndFunding() public {}

    function testWithdraw() public {
        vm.warp(block.timestamp + 3 weeks);
        vm.prank(Peter);
        fund.donate{value: 1000 ether}();

        uint256 startingContractBalance = address(fund).balance;
        uint256 startingOwnerBalance = fund.getOwner().balance;
        fund.getContractBalance();
       
        // // Act
        vm.startPrank(fund.getOwner());
        fund.withdraw();
        vm.stopPrank();

        // Assert
        uint256 endingFundMeBalance = address(fund).balance;
        uint256 endingOwnerBalance = fund.getOwner().balance;
        assertEq(endingFundMeBalance, 0);
        assertEq(
            startingContractBalance + startingOwnerBalance,
            endingOwnerBalance // + gasUsed
        );
        fund.getOwnerBalance();
    }
    
}
