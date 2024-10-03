// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {Fund} from "../src/Fund.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract Deploy is Script {
    uint256 private constant DEADLINE = 2 weeks;

    function deployFund() public returns (Fund, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig(); // This comes with our mocks!
        address priceFeed = helperConfig.getConfigByChainId(block.chainid).priceFeed;

        vm.startBroadcast();
        Fund fund = new Fund(DEADLINE, priceFeed);
        vm.stopBroadcast();
        return (fund, helperConfig);
    }

    function run() external returns (Fund, HelperConfig) {
        return deployFund();
    }
}
