// SPDX-License-Identifier: BSD 3-Clause License
pragma solidity ^0.8.24;

import {TransparentUpgradeableProxy} from
    "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "lib/openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import {BaseScript} from "script/BaseScript.s.sol";
import {stdJson} from "lib/forge-std/src/StdJson.sol";
import {PooledDepositsVault} from "src/PooledDepositsVault.sol"; // Renamed from PooledDeposits to PooledDepositsVault
import {ActorAddresses} from "script/Actors.sol";
import {console} from "lib/forge-std/src/console.sol";
import {IStakingNode} from "src/interfaces/IStakingNode.sol";
import {ISignatureUtilsMixinTypes} from "lib/eigenlayer-contracts/src/contracts/interfaces/ISignatureUtilsMixin.sol";
import {IStakingNodesManager} from "src/interfaces/IStakingNodesManager.sol";
import {ContractAddresses} from "script/ContractAddresses.sol";

interface IEigenOperator {

    /// @notice Allocate the operator set to the strategy, called by service manager.
    /// @param _operatorSetId Operator set id
    /// @param _strategy Strategy address
    function allocate(uint32 _operatorSetId, address _strategy) external;

    /// @notice Advance the TOTP
    function advanceTotp() external;

    /// @notice Get the service manager
    /// @return The service manager address
    function eigenServiceManager() external view returns (address);

    /// @notice Get the operator
    /// @return The operator or borrower address in the cap system
    function operator() external view returns (address);

    /// @notice Get the current TOTP
    /// @return The current TOTP
    function currentTotp() external view returns (uint256);

    function getCurrentTotpExpiryTimestamp() external view returns (uint256);

}

contract DelegateTransactionBuilderCap_ynLSDe is BaseScript {

    function run() external {
        address[] memory stakingNodes = new address[](5);
        stakingNodes[0] = 0x7E312a16214ceDb43E3CD68BDc508c36CfD7c356;
        stakingNodes[1] = 0x2B055a6898C0518Ed35733B162eC4C7459e9ACda;
        stakingNodes[2] = 0xb7ae463C61366214a656c7B0365F462a6ed5D180;
        stakingNodes[3] = 0x692E4991fD98c5aFB8e48f339Eda3DDd4240f0d6;
        stakingNodes[4] = 0xDc9D9eff40BA2d4c8c0816f4982a5eaE52Df8863;

        ContractAddresses contractAddresses = new ContractAddresses();
        ContractAddresses.ChainAddresses memory chainAddresses = contractAddresses.getChainAddresses(block.chainid);
        IStakingNodesManager stakingNodesManager =
            IStakingNodesManager(chainAddresses.ynEigen.TOKEN_STAKING_NODES_MANAGER_ADDRESS);
        IStakingNode[] memory allNodes = stakingNodesManager.getAllNodes();
        require(allNodes.length == stakingNodes.length, "Node count mismatch.");

        for (uint256 i = 0; i < stakingNodes.length; i++) {
            require(address(allNodes[i]) == stakingNodes[i], "Node address mismatch.");
        }

        address OPERATOR_1 = 0xAfFf8F87dB00C3C0AD3321aF7e0716A31733eF25;

        address[] memory operators = new address[](5);
        operators[0] = address(0);
        operators[1] = OPERATOR_1;
        operators[2] = address(0);
        operators[3] = address(0);
        operators[4] = address(0);

        for (uint256 i = 0; i < stakingNodes.length; i++) {
            address currentOperator = operators[i];

            if (currentOperator == address(0)) continue;

            IEigenOperator eigenOperator = IEigenOperator(currentOperator);

            uint256 currentTotpExpiryTimestamp = eigenOperator.getCurrentTotpExpiryTimestamp();
            console.log("Current TOTP expiry timestamp:", currentTotpExpiryTimestamp);

            uint256 expiry = currentTotpExpiryTimestamp;

            bytes32 approverSalt = bytes32(uint256(expiry));

            // Generate tx data for delegating to an operator
            bytes memory delegateTxData = abi.encodeWithSelector(
                IStakingNode.delegate.selector,
                currentOperator,
                ISignatureUtilsMixinTypes.SignatureWithExpiry({signature: "", expiry: expiry}),
                approverSalt
            );
            console.log("Node address:", stakingNodes[i]);
            console.log("Index:", i);
            console.log("Delegating to operator:", currentOperator);
            console.log("Delegate transaction data:", vm.toString(abi.encodePacked(delegateTxData)));
        }
    }

}
