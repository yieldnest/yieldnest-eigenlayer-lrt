// SPDX-License-Identifier: BSD 3-Clause License
pragma solidity ^0.8.24;

import {Script} from "lib/forge-std/src/Script.sol";
import {console} from "lib/forge-std/src/console.sol";
import {IEigenOperator} from "./IEigenOperator.sol";
import {IEigenServiceManager} from "./IEigenServiceManager.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IStrategy} from "@eigenlayer/src/contracts/interfaces/IStrategy.sol";
import {ITokenStakingNode} from "src/interfaces/ITokenStakingNode.sol";
import {IDelegationManager} from "@eigenlayer/src/contracts/interfaces/IDelegationManager.sol";
import {EIGEN_SERVICE_MANAGER} from "./Contracts.sol";

contract PrintOperatorState is Script {
    function run() external {
        address operator = vm.promptAddress("Enter the borrower address");
        run(operator);
    }

    function run(address operator) public {
        console.log("=== Operator State ===");
        console.log("Operator (borrower):", operator);

        address eigenOperatorAddr = EIGEN_SERVICE_MANAGER.getEigenOperator(operator);
        console.log("EigenOperator contract:", eigenOperatorAddr);

        IEigenOperator eigenOperator = IEigenOperator(eigenOperatorAddr);

        // Delegation / restaker info
        address restaker = eigenOperator.restaker();
        console.log("Restaker (delegator):", restaker);

        address serviceManager = eigenOperator.eigenServiceManager();
        console.log("Service Manager:", serviceManager);

        // TOTP state
        uint256 currentTotp = eigenOperator.currentTotp();
        uint256 totpExpiry = eigenOperator.getCurrentTotpExpiryTimestamp();
        console.log("Current TOTP:", currentTotp);
        console.log("TOTP expiry timestamp:", totpExpiry);

        // Cap / coverage info from service manager
        address strategy = EIGEN_SERVICE_MANAGER.operatorToStrategy(operator);
        console.log("Strategy:", strategy);

        address underlying = address(IStrategy(strategy).underlyingToken());
        console.log("Underlying token:", underlying);
        console.log("Token name:", IERC20Metadata(underlying).name());
        console.log("Token symbol:", IERC20Metadata(underlying).symbol());

        uint32 operatorSetId = EIGEN_SERVICE_MANAGER.operatorSetId(operator);
        console.log("Operator set ID:", operatorSetId);

        uint32 createdAt = EIGEN_SERVICE_MANAGER.createdAtEpoch(operator);
        console.log("Created at epoch:", createdAt);

        uint256 coverage = EIGEN_SERVICE_MANAGER.coverage(operator);
        console.log("Coverage:", coverage);

        uint256 slashable = EIGEN_SERVICE_MANAGER.slashableCollateral(operator, 0);
        console.log("Slashable collateral:", slashable);

        // Check if restaker is a TokenStakingNode
        try ITokenStakingNode(restaker).nodeId() returns (uint256 nodeId) {
            console.log("-------------------------------------------");
            console.log("=== TokenStakingNode State ===");
            console.log("Node ID:", nodeId);
            console.log("Delegated to:", ITokenStakingNode(restaker).delegatedTo());
            console.log("Synchronized:", ITokenStakingNode(restaker).isSynchronized());

            (uint256 queuedShares, uint256 withdrawnBalance) =
                ITokenStakingNode(restaker).getQueuedSharesAndWithdrawn(IStrategy(strategy), IERC20Metadata(underlying));
            console.log("Queued shares:", queuedShares);
            console.log("Withdrawn balance:", withdrawnBalance);

            uint256 withdrawableShares = ITokenStakingNode(restaker).getWithdrawableShares(IStrategy(strategy));
            console.log("Withdrawable shares:", withdrawableShares);

            _printQueuedWithdrawals(restaker);
            console.log("-------------------------------------------");
        } catch {
            // restaker is not a TokenStakingNode, skip
        }
    }

    function _printQueuedWithdrawals(address staker) internal view {
        IDelegationManager delegationManager =
            IDelegationManager(EIGEN_SERVICE_MANAGER.eigenAddresses().delegationManager);

        (IDelegationManager.Withdrawal[] memory withdrawals, uint256[][] memory shares) =
            delegationManager.getQueuedWithdrawals(staker);

        console.log("Queued withdrawals count:", withdrawals.length);
        for (uint256 i = 0; i < withdrawals.length; i++) {
            console.log("  Withdrawal", i);
            console.log("    Staker:", withdrawals[i].staker);
            console.log("    Delegated to:", withdrawals[i].delegatedTo);
            console.log("    Withdrawer:", withdrawals[i].withdrawer);
            console.log("    Nonce:", withdrawals[i].nonce);
            console.log("    Start block:", withdrawals[i].startBlock);
            for (uint256 j = 0; j < withdrawals[i].strategies.length; j++) {
                console.log("    Strategy:", address(withdrawals[i].strategies[j]));
                console.log("    Scaled shares:", withdrawals[i].scaledShares[j]);
                console.log("    Shares:", shares[i][j]);
            }
        }
    }
}
