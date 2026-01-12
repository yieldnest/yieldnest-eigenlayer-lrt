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

contract DelegateTransactionBuilder is BaseScript {


    function run() external {

        address[] memory stakingNodes = new address[](1);
        //stakingNodes[0] = 0x7E312a16214ceDb43E3CD68BDc508c36CfD7c356;
        // stakingNodes[1] = 0xAc4B7CA94c004A6D7cE9B62fb9d86DF8f6CcFc26;
        // stakingNodes[2] = 0xAEBDCD5285988009C1C4cC05a8DDdd29E42304C7;
        stakingNodes[0] = 0x77F7d153Bd9e25293a95AEDFE8087F3e24D73c9e;
        // stakingNodes[4] = 0xc9170a5C286a6D8C80b07d20E087e20f273A36A1;

        ContractAddresses contractAddresses = new ContractAddresses();
        ContractAddresses.ChainAddresses memory chainAddresses = contractAddresses.getChainAddresses(block.chainid);
        IStakingNodesManager stakingNodesManager = IStakingNodesManager(chainAddresses.yn.STAKING_NODES_MANAGER_ADDRESS);
        IStakingNode[] memory allNodes = stakingNodesManager.getAllNodes();
 
        IDelegationManager delegationManager = IDelegationManager(0x39053D51B77DC0d36036Fc1fCc8Cb819df8Ef37A);

        (IDelegationManager.Withdrawal[] memory withdrawals, uint256[][] memory shares) = delegationManager.getQueuedWithdrawals(stakingNodes[0]);

        for (uint256 i = 0; i < withdrawals.length; i++) {
            console.log("Withdrawal:", i, "withdrawal.withdrawer:", withdrawals[i].withdrawer);

            for (uint256 j = 0; j < withdrawals[i].strategies.length; j++) {
                console.log("   Strategy:", j, address(withdrawals[i].strategies[j]));
                console.log("   ScaledShare:", withdrawals[i].scaledShares[j]);
            }
            console.log("--------------------------------");
        }
        console.log("Withdrawals:", withdrawals.length);

        IDelegationManager.Withdrawal[] memory withdrawAsSharesOnlyWithdrawals = new IDelegationManager.Withdrawal[](1);

        withdrawAsSharesOnlyWithdrawals[0] = withdrawals[0];

        // Prepare the argument to pass for updateTokenStakingNodesBalances (set to true for this example)
        bool updateTokenStakingNodesBalances = true;

        // Encode the function call data for completeQueuedWithdrawals
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