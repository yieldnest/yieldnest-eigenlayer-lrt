// SPDX-License-Identifier: BSD 3-Clause License
pragma solidity ^0.8.24;

import {BaseYnETHScript} from "script/ynETH/BaseYnETHScript.s.sol";
import {IStakingNode} from "src/interfaces/IStakingNode.sol";
import {console} from "lib/forge-std/src/console.sol";

/// @notice Simulate updating total ETH staked, then print ynETH accounting.
/// @dev forge script script/ynETH/PrintYnETHStats.s.sol:PrintYnETHStats --rpc-url "$RPC_URL"
contract PrintYnETHStats is BaseYnETHScript {

    function getDeploymentFile() internal view override returns (string memory) {
        return string.concat(vm.projectRoot(), "/deployments/ynETH-1.json");
    }

    function run() external {
        Deployment memory deployment = loadDeployment();

        // No broadcast: this update only affects the local simulation.
        _printAmount("Total ETH staked before update (ETH)", deployment.stakingNodesManager.totalETHStaked());
        deployment.stakingNodesManager.updateTotalETHStaked();
        _printAmount("Total ETH staked after simulated update (ETH)", deployment.stakingNodesManager.totalETHStaked());

        console.log("Chain ID:", block.chainid);
        console.log("Block:", block.number);
        console.log("ynETH:", address(deployment.ynETH));
        _printAmount("Total supply (ynETH)", deployment.ynETH.totalSupply());
        uint256 totalAssets = deployment.ynETH.totalAssets();
        _printAmount("Total assets (ETH)", totalAssets);
        _printAmount("Preview deposit of 1 ETH (ynETH)", deployment.ynETH.previewDeposit(1 ether));
        _printAmount("Preview redeem of 1 ynETH (ETH)", deployment.ynETH.previewRedeem(1 ether));
        _printAmount("ynViewer rate (ETH per ynETH)", deployment.ynViewer.getRate());

        uint256 ynETHBalance = address(deployment.ynETH).balance;
        uint256 redemptionVaultBalance = address(deployment.ynETHRedemptionAssetsVaultInstance).balance;
        _printAmount("ynETH contract balance (ETH)", ynETHBalance);
        _printAmount("Redemption vault balance (ETH)", redemptionVaultBalance);

        IStakingNode[] memory nodes = deployment.stakingNodesManager.getAllNodes();
        console.log("Staking node count:", nodes.length);
        uint256 stakingNodesBalance;
        uint256 queuedShares;
        uint256 preELIP002QueuedShares;
        for (uint256 i = 0; i < nodes.length; i++) {
            console.log(string.concat("Node ", vm.toString(i), ":"), address(nodes[i]));
            uint256 balance = nodes[i].getETHBalance();
            uint256 queued = nodes[i].queuedSharesAmount();
            uint256 preELIP002Queued = nodes[i].preELIP002QueuedSharesAmount();
            _printAmount("  Balance (ETH)", balance);
            _printAmount("  Queued shares", queued);
            _printAmount("  Pre ELIP002 queued shares", preELIP002Queued);
            stakingNodesBalance += balance;
            queuedShares += queued;
            preELIP002QueuedShares += preELIP002Queued;
        }

        _printAmount("Total staking node balances (ETH)", stakingNodesBalance);
        _printAmount("Total queued shares", queuedShares);
        _printAmount("Total pre ELIP002 queued shares", preELIP002QueuedShares);
        uint256 calculatedBalance = ynETHBalance + redemptionVaultBalance + stakingNodesBalance;
        _printAmount("Sum of balances (ETH)", calculatedBalance);
        console.log("Sum of balances equals total assets:", calculatedBalance == totalAssets);
    }

    /// @dev Show all 18 decimal places alongside the raw value, including for shares.
    function _printAmount(
        string memory label,
        uint256 value
    ) internal pure {
        bytes memory fraction = new bytes(18);
        uint256 remainder = value % 1e18;
        for (uint256 i = 18; i > 0; i--) {
            fraction[i - 1] = bytes1(uint8(48 + remainder % 10));
            remainder /= 10;
        }
        console.log(
            string.concat(
                label, ": ", vm.toString(value / 1e18), ".", string(fraction), " (raw: ", vm.toString(value), ")"
            )
        );
    }

}
