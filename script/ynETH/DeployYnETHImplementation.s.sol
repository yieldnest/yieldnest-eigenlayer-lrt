// SPDX-License-Identifier: BSD 3-Clause License
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ynETH} from "src/ynETH.sol";

/// @notice Deploys only the ynETH implementation; does not upgrade or initialize a proxy.
contract DeployYnETHImplementation is Script {
    function run() external {
        address deployer = vm.envAddress("DEPLOYER_ADDRESS");
        require(deployer != address(0), "DEPLOYER_ADDRESS is zero");

        vm.startBroadcast(deployer);
        ynETH implementation = new ynETH();
        vm.stopBroadcast();

        console.log("Deployer:", deployer);
        console.log("ynETH implementation:", address(implementation));
    }
}
