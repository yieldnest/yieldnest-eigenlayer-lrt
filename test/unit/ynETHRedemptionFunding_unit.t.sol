// SPDX-License-Identifier: BSD 3-Clause License
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {
    TransparentUpgradeableProxy
} from "lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ynETH, IYnETHEvents} from "src/ynETH.sol";
import {IStakingNodesManager} from "src/interfaces/IStakingNodesManager.sol";
import {IRewardsDistributor} from "src/interfaces/IRewardsDistributor.sol";

contract RedemptionFundingManagerStub {

    address public redemptionAssetsVault;

    function setVault(
        address vault
    ) external {
        redemptionAssetsVault = vault;
    }

    function totalDeposited() external view returns (uint256) {
        return redemptionAssetsVault == address(0) ? 0 : redemptionAssetsVault.balance;
    }

}

contract RedemptionFundingReceiverStub {

    bool public reject;

    function setReject(
        bool value
    ) external {
        reject = value;
    }

    receive() external payable {
        require(!reject, "Rejected");
    }

}

/// @dev Isolated ynETH tests with minimal manager/receiver doubles; no RPC required.
contract ynETHRedemptionFundingUnitTest is Test, IYnETHEvents {

    ynETH internal token;
    RedemptionFundingManagerStub internal manager;
    RedemptionFundingReceiverStub internal vault;
    address internal admin = makeAddr("admin");
    address internal withdrawer = makeAddr("withdrawer");
    address internal user = makeAddr("user");
    bytes32 internal constant ROLE = keccak256("ETH_REDEMPTION_WITHDRAWER_ROLE");

    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

    function setUp() public {
        manager = new RedemptionFundingManagerStub();
        vault = new RedemptionFundingReceiverStub();
        manager.setVault(address(vault));
        ynETH.Init memory init = ynETH.Init({
            admin: admin,
            pauser: admin,
            unpauser: admin,
            stakingNodesManager: IStakingNodesManager(address(manager)),
            rewardsDistributor: IRewardsDistributor(makeAddr("rewards distributor")),
            pauseWhitelist: new address[](0)
        });
        token = ynETH(
            payable(address(
                    new TransparentUpgradeableProxy(
                        address(new ynETH()), admin, abi.encodeCall(ynETH.initialize, (init))
                    )
                ))
        );
        // CREATE addresses and named accounts can already hold ETH on a mainnet fork.
        // These isolated fixtures must start from the same balances with or without --rpc-url.
        vm.deal(address(manager), 0);
        vm.deal(address(vault), 0);
        vm.deal(address(token), 0);
        vm.deal(withdrawer, 0);
        vm.prank(admin);
        token.grantRole(ROLE, withdrawer);
        vm.deal(user, 100 ether);
        vm.prank(user);
        token.depositETH{value: 100 ether}(user);
    }

    function _withdraw(
        uint256 amount
    ) internal {
        vm.prank(withdrawer);
        token.withdrawETHForRedemption(amount);
    }

    function _assertBalances(
        uint256 moved
    ) internal view {
        assertEq(token.totalDepositedInPool(), 100 ether - moved);
        assertEq(address(token).balance, 100 ether - moved);
        assertEq(address(vault).balance, moved);
        assertEq(token.totalAssets(), 100 ether);
        assertEq(token.totalSupply(), 100 ether);
        assertEq(token.balanceOf(user), 100 ether);
        assertEq(token.previewRedeem(1 ether), 1 ether);
        assertEq(address(manager).balance, 0);
        assertEq(withdrawer.balance, 0);
    }

    function testFuzzTransferPreservesAssets(
        uint256 amount
    ) public {
        amount = bound(amount, 0, 100 ether);
        vm.expectEmit(true, false, false, true, address(token));
        emit ETHWithdrawnForRedemption(address(vault), amount, 100 ether - amount);
        _withdraw(amount);
        _assertBalances(amount);
    }

    function testFullPool() public {
        _withdraw(100 ether);
        _assertBalances(100 ether);
    }

    function testZeroAmount() public {
        _withdraw(0);
        _assertBalances(0);
    }

    function testFuzzSequentialTransfers(
        uint256 first,
        uint256 second
    ) public {
        first = bound(first, 0, 100 ether);
        second = bound(second, 0, 100 ether - first);
        _withdraw(first);
        _withdraw(second);
        _assertBalances(first + second);
    }

    function testFuzzUnauthorized(
        address caller,
        uint256 amount
    ) public {
        vm.assume(caller != withdrawer);
        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, caller, ROLE));
        vm.prank(caller);
        token.withdrawETHForRedemption(amount);
        _assertBalances(0);
    }

    function testAdminMustHaveExplicitRole() public {
        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, admin, ROLE));
        vm.prank(admin);
        token.withdrawETHForRedemption(1 ether);
    }

    function testCannotSelfGrantRole() public {
        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, user, bytes32(0)));
        vm.prank(user);
        token.grantRole(ROLE, user);
    }

    function testRoleRevocation() public {
        vm.prank(admin);
        token.revokeRole(ROLE, withdrawer);
        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, withdrawer, ROLE));
        _withdraw(1 ether);
        _assertBalances(0);
    }

    function testFuzzInsufficientPool(
        uint256 amount
    ) public {
        amount = bound(amount, 100 ether + 1, type(uint256).max);
        vm.expectRevert(ynETH.InsufficientBalance.selector);
        _withdraw(amount);
        _assertBalances(0);
    }

    function testCannotSpendUnaccountedETH() public {
        vm.deal(address(token), 101 ether);
        vm.expectRevert(ynETH.InsufficientBalance.selector);
        _withdraw(101 ether);
        assertEq(token.totalDepositedInPool(), 100 ether);
        assertEq(address(token).balance, 101 ether);
        assertEq(address(vault).balance, 0);
    }

    function testUnsetVault() public {
        manager.setVault(address(0));
        vm.expectRevert(ynETH.ZeroAddress.selector);
        _withdraw(1 ether);
        _assertBalances(0);
    }

    function testReceiverRevertRollsBack() public {
        vault.setReject(true);
        vm.expectRevert(ynETH.TransferFailed.selector);
        _withdraw(1 ether);
        _assertBalances(0);
    }

    function testUsesConfiguredVault() public {
        RedemptionFundingReceiverStub replacement = new RedemptionFundingReceiverStub();
        vm.deal(address(replacement), 0);
        manager.setVault(address(replacement));
        _withdraw(10 ether);
        assertEq(address(replacement).balance, 10 ether);
        assertEq(address(vault).balance, 0);
        assertEq(token.totalDepositedInPool(), 90 ether);
        assertEq(token.totalAssets(), 100 ether);
    }

}
