// SPDX-License-Identifier: BSD 3-Clause License
pragma solidity ^0.8.24;

import {Script} from "lib/forge-std/src/Script.sol";
import {console} from "lib/forge-std/src/console.sol";
import {ITokenStakingNode} from "src/interfaces/ITokenStakingNode.sol";
import {IDelegationManager} from "@eigenlayer/src/contracts/interfaces/IDelegationManager.sol";
import {EIGEN_SERVICE_MANAGER} from "./Contracts.sol";

contract CompleteQueuedWithdrawals is Script {
    function run() external {
        address stakingNode = vm.promptAddress("Enter the TokenStakingNode address");
        run(stakingNode);
    }

    function run(address stakingNode) public {
        ITokenStakingNode node = ITokenStakingNode(stakingNode);
        IDelegationManager delegationManager =
            IDelegationManager(EIGEN_SERVICE_MANAGER.eigenAddresses().delegationManager);

        console.log("=== Complete Queued Withdrawals ===");
        console.log("TokenStakingNode:", stakingNode);
        console.log("Node ID:", node.nodeId());
        console.log("Synchronized:", node.isSynchronized());

        (IDelegationManager.Withdrawal[] memory withdrawals, uint256[][] memory shares) =
            delegationManager.getQueuedWithdrawals(stakingNode);

        console.log("Queued withdrawals count:", withdrawals.length);
        require(withdrawals.length > 0, "No queued withdrawals");

        for (uint256 i = 0; i < withdrawals.length; i++) {
            console.log("---");
            console.log("  Withdrawal", i);
            console.log("    Staker:", withdrawals[i].staker);
            console.log("    Delegated to:", withdrawals[i].delegatedTo);
            console.log("    Nonce:", withdrawals[i].nonce);
            console.log("    Start block:", withdrawals[i].startBlock);
            for (uint256 j = 0; j < withdrawals[i].strategies.length; j++) {
                console.log("    Strategy:", address(withdrawals[i].strategies[j]));
                console.log("    Scaled shares:", withdrawals[i].scaledShares[j]);
                console.log("    Shares:", shares[i][j]);
            }
        }

        bytes memory callData = abi.encodeWithSelector(
            ITokenStakingNode.completeQueuedWithdrawalsAsShares.selector,
            withdrawals
        );

        console.log("---");
        console.log("Target:", stakingNode);
        console.log("Call data:", vm.toString(callData));
    }
}
