// SPDX-License-Identifier: BSD 3-Clause License
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

interface IYnETHStatus {

    function totalAssets() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function previewRedeem(
        uint256 shares
    ) external view returns (uint256);
    function stakingNodesManager() external view returns (address);

}

interface IYnETHManagerStatus {

    function redemptionAssetsVault() external view returns (address);
    function totalETHStaked() external view returns (uint256);

}

/// @notice Read mainnet ynETH balances without broadcasting or updating cached accounting.
/// @dev Run: forge script script/ynETH/PrintYnETHStatus.s.sol:PrintYnETHStatus --rpc-url "$MAINNET_RPC_URL"
contract PrintYnETHStatus is Script {

    address internal constant YNETH = 0x09db87A538BD693E9d08544577d5cCfAA6373A48;

    function run() external view {
        require(block.chainid == 1, "Use an Ethereum mainnet RPC");
        IYnETHStatus token = IYnETHStatus(YNETH);
        IYnETHManagerStatus manager = IYnETHManagerStatus(token.stakingNodesManager());
        address vault = manager.redemptionAssetsVault();

        console.log("Mainnet block:", block.number);
        console.log("ynETH:", YNETH);
        console.log("Redemption assets vault:", vault);
        console.log("Total assets (ETH):", _format(token.totalAssets()));
        console.log("Total supply (ynETH):", _format(token.totalSupply()));
        console.log("Rate (ETH per 1 ynETH):", _format(token.previewRedeem(1 ether)));
        console.log("ETH in ynETH deposit pool:", _format(YNETH.balance));
        console.log("ETH in redemption assets vault:", _format(vault.balance));
        console.log("Total ETH staked (cached accounting):", _format(manager.totalETHStaked()));
    }

    function _format(
        uint256 amount
    ) internal pure returns (string memory) {
        bytes memory fraction = new bytes(18);
        uint256 remainder = amount % 1 ether;
        for (uint256 i = 18; i > 0; --i) {
            fraction[i - 1] = bytes1(uint8(48 + remainder % 10));
            remainder /= 10;
        }
        return string.concat(vm.toString(amount / 1 ether), ".", string(fraction));
    }

}
