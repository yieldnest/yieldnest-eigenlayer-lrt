// SPDX-License-Identifier: BSD 3-Clause License
pragma solidity ^0.8.24;

import {Script} from "lib/forge-std/src/Script.sol";
import {console} from "lib/forge-std/src/console.sol";
import {IEigenOperator} from "./IEigenOperator.sol";

contract AdvanceTotp is Script {
    function run() external {
        address eigenOperatorAddress = vm.promptAddress("Enter the IEigenOperator address");

        IEigenOperator eigenOperator = IEigenOperator(eigenOperatorAddress);

        console.log("EigenOperator address:", eigenOperatorAddress);
        console.log("Current TOTP:", eigenOperator.currentTotp());
        console.log("Current TOTP expiry:", eigenOperator.getCurrentTotpExpiryTimestamp());

        vm.startBroadcast();

        eigenOperator.advanceTotp();

        vm.stopBroadcast();

        console.log("TOTP advanced successfully");
        console.log("New TOTP:", eigenOperator.currentTotp());
        console.log("New TOTP expiry:", eigenOperator.getCurrentTotpExpiryTimestamp());
    }
}
