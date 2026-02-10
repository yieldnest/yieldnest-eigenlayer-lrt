// SPDX-License-Identifier: BSD 3-Clause License
pragma solidity ^0.8.24;

import {Script} from "lib/forge-std/src/Script.sol";
import {console} from "lib/forge-std/src/console.sol";
import {IEigenOperator} from "./IEigenOperator.sol";
import {IEigenServiceManager} from "./IEigenServiceManager.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {EIGEN_SERVICE_MANAGER} from "./Contracts.sol";

interface IStrategy {
    function underlyingToken() external view returns (address);
}

contract PrintOperatorState is Script {
    function run() external {
        address operator = vm.promptAddress("Enter the borrower address");
        run(operator);
    }

    function run(address operator) public view {
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

        address underlying = IStrategy(strategy).underlyingToken();
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
    }
}
