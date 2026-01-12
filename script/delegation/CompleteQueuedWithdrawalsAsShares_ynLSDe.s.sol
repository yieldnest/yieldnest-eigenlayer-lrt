// SPDX-License-Identifier: BSD 3-Clause License
pragma solidity ^0.8.24;

import {TransparentUpgradeableProxy} from "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
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
import {IDelegationManager} from "lib/eigenlayer-contracts/src/contracts/interfaces/IDelegationManager.sol";
import {ITokenStakingNode} from "src/interfaces/ITokenStakingNode.sol";

contract CompleteQueuedWithdrawalsAsShares_ynLSDe is BaseScript {


    function run() external {

        address[] memory stakingNodes = new address[](5);
        stakingNodes[0] = 0x7E312a16214ceDb43E3CD68BDc508c36CfD7c356;
        stakingNodes[1] = 0x2B055a6898C0518Ed35733B162eC4C7459e9ACda;
        stakingNodes[2] = 0xb7ae463C61366214a656c7B0365F462a6ed5D180;
        stakingNodes[3] = 0x692E4991fD98c5aFB8e48f339Eda3DDd4240f0d6;
        stakingNodes[4] = 0xDc9D9eff40BA2d4c8c0816f4982a5eaE52Df8863;

        ContractAddresses contractAddresses = new ContractAddresses();
        ContractAddresses.ChainAddresses memory chainAddresses = contractAddresses.getChainAddresses(block.chainid);
        IStakingNodesManager stakingNodesManager = IStakingNodesManager(chainAddresses.yn.STAKING_NODES_MANAGER_ADDRESS);
        IStakingNode[] memory allNodes = stakingNodesManager.getAllNodes();
 
        IDelegationManager delegationManager = IDelegationManager(0x39053D51B77DC0d36036Fc1fCc8Cb819df8Ef37A);

        (IDelegationManager.Withdrawal[] memory withdrawals, uint256[][] memory shares) = delegationManager.getQueuedWithdrawals(stakingNodes[1]);

        for (uint256 i = 0; i < withdrawals.length; i++) {
            console.log("Withdrawal:", i, "withdrawal.withdrawer:", withdrawals[i].withdrawer);

            for (uint256 j = 0; j < withdrawals[i].strategies.length; j++) {
                console.log("   Strategy:", j, address(withdrawals[i].strategies[j]));
                console.log("   ScaledShare:", withdrawals[i].scaledShares[j]);
            }
            console.log("--------------------------------");
        }
        console.log("Withdrawals:", withdrawals.length);

        IDelegationManager.Withdrawal[] memory withdrawAsSharesOnlyWithdrawals = withdrawals;

        console.log("Withdrawals length:", withdrawAsSharesOnlyWithdrawals.length);

        // Prepare the argument to pass for updateTokenStakingNodesBalances (set to true for this example)
        bool updateTokenStakingNodesBalances = true;

        // Encode the function call data for completeQueuedWithdrawalsAsShares
        bytes memory completeQueuedWithdrawalsTxData = abi.encodeWithSelector(
            ITokenStakingNode.completeQueuedWithdrawalsAsShares.selector,
            withdrawAsSharesOnlyWithdrawals,
            updateTokenStakingNodesBalances
        );

        // Print details and tx data
        console.log("StakingNode address:", stakingNodes[0]);
        console.log(
            "completeQueuedWithdrawals() tx data:",
            vm.toString(abi.encodePacked(completeQueuedWithdrawalsTxData))
        );

    }

}