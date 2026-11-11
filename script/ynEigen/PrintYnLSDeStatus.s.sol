// SPDX-License-Identifier: BSD 3-Clause License
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

interface IYnLSDeStatusToken {

    function totalSupply() external view returns (uint256);
    function totalAssets() external view returns (uint256);
    function previewRedeem(
        uint256 shares
    ) external view returns (uint256);
    function assetRegistry() external view returns (address);
    function yieldNestStrategyManager() external view returns (address);
    function assetBalances(
        address[] calldata assets
    ) external view returns (uint256[] memory);

}

interface IYnLSDeStatusRegistry {

    function getAssets() external view returns (address[] memory);
    function getAllAssetBalances() external view returns (uint256[] memory);
    function convertToUnitOfAccount(
        address asset,
        uint256 amount
    ) external view returns (uint256);

}

interface IYnLSDeStatusManager {

    function tokenStakingNodesManager() external view returns (address);
    function redemptionAssetsVault() external view returns (address);
    function wrapper() external view returns (address);
    function strategies(
        address asset
    ) external view returns (address);
    function getStakedAssetsBalances(
        address[] calldata assets
    ) external view returns (uint256[] memory);

}

interface IYnLSDeStatusNodes {

    function getAllNodes() external view returns (address[] memory);

}

interface IYnLSDeStatusNode {

    function nodeId() external view returns (uint256);
    function delegatedTo() external view returns (address);
    function isSynchronized() external view returns (bool);
    function getWithdrawableShares(
        address strategy
    ) external view returns (uint256);
    function getQueuedSharesAndWithdrawn(
        address strategy,
        address asset
    ) external view returns (uint256, uint256);

}

interface IYnLSDeStatusStrategy {

    function underlyingToken() external view returns (address);
    function sharesToUnderlyingView(
        uint256 shares
    ) external view returns (uint256);

}

interface IYnLSDeStatusAsset {

    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);

}

interface IYnLSDeStatusWrapper {

    function toUserAssetAmount(
        address asset,
        uint256 amount
    ) external view returns (uint256);

}

interface IYnLSDeStatusVault {

    function redeemer() external view returns (address);
    function availableRedemptionAssets() external view returns (uint256);
    function assetBalances(
        address[] calldata assets
    ) external view returns (uint256[] memory);

}

interface IYnLSDeStatusQueue {

    function _tokenIdCounter() external view returns (uint256);
    function lastFinalizedIndex() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function pendingRequestedRedemptionAmount() external view returns (uint256);

}

/// @notice Read mainnet ynLSDe status, including manually queued/completed withdrawals.
/// @dev forge script script/ynEigen/PrintYnLSDeStatus.s.sol:PrintYnLSDeStatus --rpc-url "$RPC_URL"
///      No broadcast, synchronization, role checks or deployment JSON files are needed.
contract PrintYnLSDeStatus is Script {

    address internal constant YNLSDE = 0x35Ec69A77B79c255e5d47D5A3BdbEFEfE342630c;

    struct Context {
        IYnLSDeStatusRegistry registry;
        IYnLSDeStatusManager manager;
        IYnLSDeStatusWrapper wrapper;
        address[] nodes;
        address[] assets;
    }

    function run() external view {
        require(block.chainid == 1, "Use an Ethereum mainnet RPC");
        IYnLSDeStatusToken token = IYnLSDeStatusToken(YNLSDE);
        IYnLSDeStatusManager manager = IYnLSDeStatusManager(token.yieldNestStrategyManager());
        IYnLSDeStatusRegistry registry = IYnLSDeStatusRegistry(token.assetRegistry());
        Context memory ctx = Context({
            registry: registry,
            manager: manager,
            wrapper: IYnLSDeStatusWrapper(manager.wrapper()),
            nodes: IYnLSDeStatusNodes(manager.tokenStakingNodesManager()).getAllNodes(),
            assets: registry.getAssets()
        });

        console.log("=== ynLSDe status (read only) ===");
        console.log("Chain ID:", block.chainid);
        console.log("Block:", block.number);
        console.log("Block timestamp:", block.timestamp);
        console.log("ynLSDe:", YNLSDE);
        console.log("Strategy manager:", address(manager));
        _printAmount("Total supply (ynLSDe)", token.totalSupply(), 18);
        _printAmount("Total assets (ETH, reported accounting)", token.totalAssets(), 18);
        _printAmount("Rate (ETH per ynLSDe)", token.previewRedeem(1 ether), 18);
        console.log("Node count:", ctx.nodes.length);

        for (uint256 i; i < ctx.nodes.length; ++i) {
            _printNode(ctx, ctx.nodes[i]);
        }
        _printAssetTotals(ctx, token);
        _printWithdrawalQueue(IYnLSDeStatusVault(manager.redemptionAssetsVault()));
    }

    function _printNode(
        Context memory ctx,
        address nodeAddress
    ) internal view {
        IYnLSDeStatusNode node = IYnLSDeStatusNode(nodeAddress);
        console.log("\n=== Node ===");
        console.log("ID:", node.nodeId());
        console.log("Address:", nodeAddress);
        console.log("Delegated to (node accounting):", node.delegatedTo());
        console.log("Delegation synchronized:", node.isSynchronized());
        for (uint256 j; j < ctx.assets.length; ++j) {
            address asset = ctx.assets[j];
            address strategyAddress = ctx.manager.strategies(asset);
            IYnLSDeStatusStrategy strategy = IYnLSDeStatusStrategy(strategyAddress);
            address underlying = strategy.underlyingToken();
            uint256 staked = node.getWithdrawableShares(strategyAddress);
            (uint256 queued, uint256 withdrawn) = node.getQueuedSharesAndWithdrawn(strategyAddress, asset);
            console.log("Asset:", IYnLSDeStatusAsset(asset).symbol());
            console.log("  Strategy:", strategyAddress);
            console.log("  EigenLayer underlying:", IYnLSDeStatusAsset(underlying).symbol());
            console.log("  Withdrawable strategy shares (raw):", staked);
            console.log("  Queued strategy shares (node accounting, raw):", queued);
            _printAmount(
                "  Staked underlying tokens (live)",
                strategy.sharesToUnderlyingView(staked),
                IYnLSDeStatusAsset(underlying).decimals()
            );
            _printAmount(
                "  Queued underlying tokens (node accounting)",
                strategy.sharesToUnderlyingView(queued),
                IYnLSDeStatusAsset(underlying).decimals()
            );
            _printAmount(
                "  Completed withdrawals on node (asset tokens)", withdrawn, IYnLSDeStatusAsset(asset).decimals()
            );
        }
    }

    function _printAssetTotals(
        Context memory ctx,
        IYnLSDeStatusToken token
    ) internal view {
        uint256[] memory totalBalances = ctx.registry.getAllAssetBalances();
        uint256[] memory cachedNodeBalances = ctx.manager.getStakedAssetsBalances(ctx.assets);
        uint256[] memory idleBalances = token.assetBalances(ctx.assets);
        uint256[] memory vaultBalances =
            IYnLSDeStatusVault(ctx.manager.redemptionAssetsVault()).assetBalances(ctx.assets);
        for (uint256 j; j < ctx.assets.length; ++j) {
            address asset = ctx.assets[j];
            uint8 decimals = IYnLSDeStatusAsset(asset).decimals();
            console.log("\n=== Asset totals ===");
            console.log("Asset:", IYnLSDeStatusAsset(asset).symbol());
            console.log("Address:", asset);
            _printAmount("Idle in ynLSDe (accounted tokens)", idleBalances[j], decimals);
            _printAmount("In redemption vault (accounted tokens)", vaultBalances[j], decimals);
            _printAmount("All nodes incl. queued/completed (cached asset tokens)", cachedNodeBalances[j], decimals);
            _printLiveNodeTotals(ctx, asset, decimals);
            _printAmount("System total (reported asset tokens)", totalBalances[j], decimals);
            _printAmount(
                "System total (reported ETH equivalent)",
                ctx.registry.convertToUnitOfAccount(asset, totalBalances[j]),
                18
            );
        }
        console.log("Reported totals use cached strategy accounting; this script does not update it.");
        console.log(
            "Queued balances use node accounting; delegation synchronized does not certify slashing accounting."
        );
    }

    function _printLiveNodeTotals(
        Context memory ctx,
        address asset,
        uint8 decimals
    ) internal view {
        IYnLSDeStatusStrategy strategy = IYnLSDeStatusStrategy(ctx.manager.strategies(asset));
        uint256 staked;
        uint256 queued;
        uint256 withdrawn;
        for (uint256 i; i < ctx.nodes.length; ++i) {
            IYnLSDeStatusNode node = IYnLSDeStatusNode(ctx.nodes[i]);
            (uint256 shares, uint256 amount) = node.getQueuedSharesAndWithdrawn(address(strategy), asset);
            staked += ctx.wrapper
                .toUserAssetAmount(
                    asset, strategy.sharesToUnderlyingView(node.getWithdrawableShares(address(strategy)))
                );
            queued += ctx.wrapper.toUserAssetAmount(asset, strategy.sharesToUnderlyingView(shares));
            withdrawn += amount;
        }
        _printAmount("Staked across nodes (live asset-token equivalent)", staked, decimals);
        _printAmount("Queued across nodes (node-accounted asset-token equivalent)", queued, decimals);
        _printAmount("Completed across nodes (asset tokens)", withdrawn, decimals);
    }

    function _printWithdrawalQueue(
        IYnLSDeStatusVault vault
    ) internal view {
        IYnLSDeStatusQueue queue = IYnLSDeStatusQueue(vault.redeemer());
        uint256 requested = queue._tokenIdCounter();
        uint256 finalized = queue.lastFinalizedIndex();
        uint256 outstanding = queue.totalSupply();
        uint256 pending = queue.pendingRequestedRedemptionAmount();
        uint256 available = vault.availableRedemptionAssets();
        console.log("\n=== User withdrawals ===");
        console.log("Redemption vault:", address(vault));
        console.log("Withdrawal queue:", address(queue));
        console.log("Next request ID:", requested);
        console.log("Last finalized index (exclusive):", finalized);
        console.log("Unfinalized requests:", requested - finalized);
        console.log("Outstanding requests incl. finalized/unclaimed:", outstanding);
        console.log("Finalized but unclaimed requests:", outstanding - (requested - finalized));
        _printAmount("Pending requested redemption value (ETH)", pending, 18);
        _printAmount("Available redemption assets (ETH)", available, 18);
        _printAmount(
            "Vault shortfall before in-flight withdrawals (ETH)", pending > available ? pending - available : 0, 18
        );
    }

    function _printAmount(
        string memory label,
        uint256 amount,
        uint8 decimals
    ) internal pure {
        uint256 scale = 10 ** uint256(decimals);
        bytes memory fraction = new bytes(decimals);
        uint256 remainder = amount % scale;
        for (uint256 i = decimals; i > 0; --i) {
            fraction[i - 1] = bytes1(uint8(48 + remainder % 10));
            remainder /= 10;
        }
        console.log(
            string.concat(
                label,
                ": ",
                vm.toString(amount / scale),
                decimals == 0 ? "" : ".",
                string(fraction),
                " (raw: ",
                vm.toString(amount),
                ")"
            )
        );
    }

}
