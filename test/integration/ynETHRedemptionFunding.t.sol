// SPDX-License-Identifier: BSD 3-Clause License
pragma solidity ^0.8.24;

import {IntegrationBaseTest} from "./IntegrationBaseTest.sol";

/// @dev Exercises the actual ynETH, manager, redemption vault and withdrawal queue together.
contract ynETHRedemptionFundingIntegrationTest is IntegrationBaseTest {

    address internal withdrawer;
    address internal firstUser;
    address internal newUser;

    function setUp() public override {
        super.setUp();
        withdrawer = makeAddr("redemption withdrawer");
        firstUser = makeAddr("first depositor");
        newUser = makeAddr("new depositor");
        bytes32 role = yneth.ETH_REDEMPTION_WITHDRAWER_ROLE();
        vm.prank(actors.admin.ADMIN);
        yneth.grantRole(role, withdrawer);
    }

    function _deposit(
        address user,
        uint256 amount
    ) internal returns (uint256 shares) {
        vm.deal(user, amount);
        vm.prank(user);
        return yneth.depositETH{value: amount}(user);
    }

    function _fundVault(
        uint256 amount
    ) internal {
        uint256 assetsBefore = yneth.totalAssets();
        stakingNodesManager.updateTotalETHStaked();
        assertEq(yneth.totalAssets(), assetsBefore, "Pre-funding staking update preserves assets");
        uint256 supplyBefore = yneth.totalSupply();
        uint256 rateBefore = yneth.previewRedeem(1 ether);
        uint256 poolBefore = yneth.totalDepositedInPool();
        uint256 vaultBefore = ynETHRedemptionAssetsVaultInstance.availableRedemptionAssets();
        uint256 managerBefore = address(stakingNodesManager).balance;
        uint256 stakedBefore = stakingNodesManager.totalETHStaked();
        vm.prank(withdrawer);
        yneth.withdrawETHForRedemption(amount);
        assertEq(yneth.totalAssets(), assetsBefore, "Funding preserves assets exactly");
        stakingNodesManager.updateTotalETHStaked();
        assertEq(yneth.totalAssets(), assetsBefore, "Post-funding staking update preserves assets");
        assertEq(yneth.totalSupply(), supplyBefore);
        assertEq(yneth.previewRedeem(1 ether), rateBefore);
        assertEq(yneth.totalDepositedInPool(), poolBefore - amount);
        assertEq(ynETHRedemptionAssetsVaultInstance.availableRedemptionAssets(), vaultBefore + amount);
        assertEq(address(stakingNodesManager).balance, managerBefore);
        assertEq(stakingNodesManager.totalETHStaked(), stakedBefore, "No staking required");
    }

    function testFuzzNewDepositAndFunding(
        uint256 initial,
        uint256 additional,
        uint256 amount
    ) public {
        initial = bound(initial, 1 gwei, 10_000 ether);
        additional = bound(additional, 1 gwei, 10_000 ether);
        _deposit(firstUser, initial);
        _fundVault(initial / 2);
        uint256 assetsBefore = yneth.totalAssets();
        uint256 expectedShares = yneth.previewDeposit(additional);
        assertEq(_deposit(newUser, additional), expectedShares);
        assertEq(yneth.totalAssets(), assetsBefore + additional);
        _fundVault(bound(amount, 0, yneth.totalDepositedInPool()));
        _fundVault(yneth.totalDepositedInPool());
        assertEq(yneth.balanceOf(newUser), expectedShares);
        assertEq(yneth.totalAssets(), initial + additional);
        assertEq(ynETHRedemptionAssetsVaultInstance.availableRedemptionAssets(), initial + additional);
    }

    function testDepositAfterPoolFullyMoved() public {
        _deposit(firstUser, 121.033_610_355_095_273_97 ether);
        _fundVault(yneth.totalDepositedInPool());
        assertEq(yneth.totalDepositedInPool(), 0);
        uint256 expectedShares = yneth.previewDeposit(5 ether);
        assertEq(_deposit(newUser, 5 ether), expectedShares);
        _fundVault(5 ether);
        assertEq(yneth.totalDepositedInPool(), 0);
    }

    function testFundVaultThenCompleteUserRedemption() public {
        _deposit(firstUser, 100 ether);
        uint256 shares = _deposit(newUser, 10 ether);
        vm.prank(actors.admin.UNPAUSE_ADMIN);
        yneth.unpauseTransfers();
        vm.startPrank(newUser);
        yneth.approve(address(ynETHWithdrawalQueueManager), shares);
        uint256 tokenId = ynETHWithdrawalQueueManager.requestWithdrawal(shares);
        vm.stopPrank();

        uint256 assetsBefore = yneth.totalAssets();
        uint256 supplyBefore = yneth.totalSupply();
        uint256 grossAmount = yneth.previewRedeem(shares);
        _fundVault(grossAmount);
        vm.prank(actors.ops.REQUEST_FINALIZER);
        ynETHWithdrawalQueueManager.finalizeRequestsUpToIndex(tokenId + 1);
        uint256 fee =
            grossAmount * ynETHWithdrawalQueueManager.withdrawalFee() / ynETHWithdrawalQueueManager.FEE_PRECISION();
        uint256 feeReceiverBefore = actors.admin.FEE_RECEIVER.balance;
        uint256 userBefore = newUser.balance;
        vm.prank(newUser);
        ynETHWithdrawalQueueManager.claimWithdrawal(tokenId, newUser);

        assertEq(newUser.balance, userBefore + grossAmount - fee);
        assertEq(actors.admin.FEE_RECEIVER.balance, feeReceiverBefore + fee);
        assertEq(yneth.totalAssets(), assetsBefore - grossAmount, "Only actual redemption reduces assets");
        assertEq(yneth.totalSupply(), supplyBefore - shares);
        assertEq(ynETHRedemptionAssetsVaultInstance.availableRedemptionAssets(), 0);
        assertEq(ynETHWithdrawalQueueManager.pendingRequestedRedemptionAmount(), 0);
        assertEq(stakingNodesManager.totalETHStaked(), 0);
    }

}
