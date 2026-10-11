// SPDX-License-Identifier: BSD 3-Clause License
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ProxyAdmin} from "lib/openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import {
    ITransparentUpgradeableProxy
} from "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ynETH, IYnETHEvents} from "src/ynETH.sol";
import {IStakingNodesManager} from "src/interfaces/IStakingNodesManager.sol";

/// @dev Run against an Ethereum mainnet fork. Only ynETH is upgraded; manager, vault and balances remain live state.
contract RedemptionFundingForkTest is Test, IYnETHEvents {

    ynETH internal token = ynETH(payable(0x09db87A538BD693E9d08544577d5cCfAA6373A48));
    address internal constant ADMIN = 0xfcad670592a3b24869C0b51a6c6FDED4F95D6975;
    bytes32 internal constant ADMIN_SLOT = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);
    address internal withdrawer;
    address internal vault;
    bytes32 internal role;

    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

    function setUp() public {
        require(block.chainid == 1, "Run with --fork-url MAINNET_RPC_URL");
        uint256 assetsBefore = token.totalAssets();
        uint256 supplyBefore = token.totalSupply();
        uint256 poolBefore = token.totalDepositedInPool();
        ProxyAdmin proxyAdmin = ProxyAdmin(address(uint160(uint256(vm.load(address(token), ADMIN_SLOT)))));
        ynETH implementation = new ynETH();
        vm.prank(proxyAdmin.owner());
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(address(token)), address(implementation), "");
        assertEq(token.totalAssets(), assetsBefore, "Upgrade preserves assets");
        assertEq(token.totalSupply(), supplyBefore, "Upgrade preserves supply");
        assertEq(token.totalDepositedInPool(), poolBefore, "Upgrade preserves pool accounting");

        vault = address(token.stakingNodesManager().redemptionAssetsVault());
        withdrawer = makeAddr("redemption withdrawer");
        role = token.ETH_REDEMPTION_WITHDRAWER_ROLE();
        assertEq(role, keccak256("ETH_REDEMPTION_WITHDRAWER_ROLE"));
        assertFalse(token.hasRole(role, ADMIN), "Role must be explicitly granted");
        vm.prank(ADMIN);
        token.grantRole(role, withdrawer);
    }

    function _withdrawAndAssert(
        uint256 amount
    ) internal {
        uint256 assetsBefore = token.totalAssets();
        token.stakingNodesManager().updateTotalETHStaked();
        assertEq(token.totalAssets(), assetsBefore, "Pre-funding staking update preserves assets");
        uint256 supplyBefore = token.totalSupply();
        uint256 rateBefore = token.previewRedeem(1 ether);
        uint256 poolBefore = token.totalDepositedInPool();
        uint256 liquidBefore = address(token).balance;
        uint256 vaultBefore = vault.balance;
        uint256 managerBefore = address(token.stakingNodesManager()).balance;
        uint256 callerBefore = withdrawer.balance;

        vm.expectEmit(true, false, false, true, address(token));
        emit ETHWithdrawnForRedemption(vault, amount, poolBefore - amount);
        vm.prank(withdrawer);
        token.withdrawETHForRedemption(amount);

        assertEq(token.totalAssets(), assetsBefore, "Total assets must stay exactly stable");
        token.stakingNodesManager().updateTotalETHStaked();
        assertEq(token.totalAssets(), assetsBefore, "Post-funding staking update preserves assets");
        assertEq(token.totalSupply(), supplyBefore, "No shares minted or burned");
        assertEq(token.previewRedeem(1 ether), rateBefore, "Share price stays stable");
        assertEq(token.totalDepositedInPool(), poolBefore - amount, "Pool accounting decreases");
        assertEq(address(token).balance, liquidBefore - amount, "Pool ETH decreases");
        assertEq(vault.balance, vaultBefore + amount, "Vault receives the exact amount");
        assertEq(address(token.stakingNodesManager()).balance, managerBefore, "Manager receives no ETH");
        assertEq(withdrawer.balance, callerBefore, "Caller receives no ETH");
    }

    function testWithdrawCurrentMainnetPool() public {
        uint256 pool = token.totalDepositedInPool();
        assertGt(pool, 0, "Mainnet pool must be funded");
        _withdrawAndAssert(pool);
        assertEq(token.totalDepositedInPool(), 0);
    }

    function testFuzzWithdrawPreservesTotalAssets(
        uint256 amount
    ) public {
        _withdrawAndAssert(bound(amount, 0, token.totalDepositedInPool()));
    }

    function testWithdrawZero() public {
        _withdrawAndAssert(0);
    }

    function testFuzzDepositThenWithdraw(
        uint256 depositAmount,
        uint256 withdrawalAmount
    ) public {
        depositAmount = bound(depositAmount, 1 gwei, 10_000 ether);
        address user = makeAddr("new depositor");
        uint256 assetsBefore = token.totalAssets();
        uint256 supplyBefore = token.totalSupply();
        uint256 poolBefore = token.totalDepositedInPool();
        uint256 expectedShares = token.previewDeposit(depositAmount);
        vm.deal(user, depositAmount);
        vm.prank(user);
        uint256 shares = token.depositETH{value: depositAmount}(user);
        assertEq(shares, expectedShares);
        assertEq(token.balanceOf(user), shares);
        assertEq(token.totalSupply(), supplyBefore + shares);
        assertEq(token.totalAssets(), assetsBefore + depositAmount);
        assertEq(token.totalDepositedInPool(), poolBefore + depositAmount);

        _withdrawAndAssert(bound(withdrawalAmount, 0, poolBefore + depositAmount));
        assertEq(token.balanceOf(user), shares, "User retains all shares");
        // Drain any remainder too, including all of the new deposit.
        _withdrawAndAssert(token.totalDepositedInPool());
        assertEq(token.totalAssets(), assetsBefore + depositAmount);
    }

    function testDepositAfterDrainingPool() public {
        _withdrawAndAssert(token.totalDepositedInPool());
        address user = makeAddr("depositor after drain");
        uint256 expectedShares = token.previewDeposit(5 ether);
        vm.deal(user, 5 ether);
        vm.prank(user);
        assertEq(token.depositETH{value: 5 ether}(user), expectedShares);
        _withdrawAndAssert(5 ether);
    }

    function testFuzzUnauthorizedCaller(
        address caller,
        uint256 amount
    ) public {
        vm.assume(!token.hasRole(role, caller));
        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, caller, role));
        vm.prank(caller);
        token.withdrawETHForRedemption(amount);
    }

    function testAdminCannotWithdrawWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, ADMIN, role));
        vm.prank(ADMIN);
        token.withdrawETHForRedemption(1 ether);
    }

    function testRevokedRoleCannotWithdraw() public {
        vm.prank(ADMIN);
        token.revokeRole(role, withdrawer);
        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, withdrawer, role));
        vm.prank(withdrawer);
        token.withdrawETHForRedemption(1 ether);
    }

    function testFuzzInsufficientPool(
        uint256 amount
    ) public {
        uint256 pool = token.totalDepositedInPool();
        amount = bound(amount, pool + 1, type(uint256).max);
        uint256 assets = token.totalAssets();
        uint256 vaultBalance = vault.balance;
        vm.expectRevert(ynETH.InsufficientBalance.selector);
        vm.prank(withdrawer);
        token.withdrawETHForRedemption(amount);
        assertEq(token.totalDepositedInPool(), pool);
        assertEq(token.totalAssets(), assets);
        assertEq(vault.balance, vaultBalance);
    }

    function testZeroVaultReverts() public {
        vm.mockCall(
            address(token.stakingNodesManager()),
            abi.encodeCall(IStakingNodesManager.redemptionAssetsVault, ()),
            abi.encode(address(0))
        );
        vm.expectRevert(ynETH.ZeroAddress.selector);
        vm.prank(withdrawer);
        token.withdrawETHForRedemption(1 ether);
    }

    function testRevertingTransferRollsBackAccounting() public {
        uint256 pool = token.totalDepositedInPool();
        uint256 assets = token.totalAssets();
        uint256 liquid = address(token).balance;
        uint256 vaultBalance = vault.balance;
        vm.etch(vault, hex"60006000fd"); // Receiver reverts on every call.
        vm.expectRevert(ynETH.TransferFailed.selector);
        vm.prank(withdrawer);
        token.withdrawETHForRedemption(pool);
        assertEq(token.totalDepositedInPool(), pool);
        assertEq(address(token).balance, liquid);
        assertEq(vault.balance, vaultBalance);
        // Restore the vault getter to verify assets after the reverted transfer.
        vm.mockCall(vault, abi.encodeWithSignature("availableRedemptionAssets()"), abi.encode(vaultBalance));
        assertEq(token.totalAssets(), assets);
    }

}
