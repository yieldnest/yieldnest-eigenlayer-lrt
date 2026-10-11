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
import {IEigenOperator} from "script/delegation/IEigenOperator.sol";
import {IEigenServiceManager} from "script/delegation/IEigenServiceManager.sol";
import {EIGEN_SERVICE_MANAGER} from "script/delegation/Contracts.sol";

contract DelegateToCapOperator is BaseScript {


    function run() external {

        uint256 nodeCount = 5;
        address[] memory stakingNodes = new address[](nodeCount);
        uint256 index = 0;
        stakingNodes[index++] = 0x7E312a16214ceDb43E3CD68BDc508c36CfD7c356;
        stakingNodes[index++] = 0x2B055a6898C0518Ed35733B162eC4C7459e9ACda;
        stakingNodes[index++] = 0xb7ae463C61366214a656c7B0365F462a6ed5D180;
        stakingNodes[index++] = 0x692E4991fD98c5aFB8e48f339Eda3DDd4240f0d6;
        stakingNodes[index] = 0xDc9D9eff40BA2d4c8c0816f4982a5eaE52Df8863;

        ContractAddresses contractAddresses = new ContractAddresses();
        ContractAddresses.ChainAddresses memory chainAddresses = contractAddresses.getChainAddresses(block.chainid);
        IStakingNodesManager stakingNodesManager = IStakingNodesManager(chainAddresses.ynEigen.TOKEN_STAKING_NODES_MANAGER_ADDRESS);
        IStakingNode[] memory allNodes = stakingNodesManager.getAllNodes();
        require(allNodes.length == stakingNodes.length, "Node count mismatch.");

        for (uint i = 0; i < stakingNodes.length; i++) {
            require(address(allNodes[i]) == stakingNodes[i], "Node address mismatch.");
        }

        address[] memory operators = new address[](nodeCount);
        uint256 operatorIndex = 0;
        operators[operatorIndex++] = address(0);
        operators[operatorIndex++] = 0xAfFf8F87dB00C3C0AD3321aF7e0716A31733eF25;
        operators[operatorIndex++] = address(0);
        operators[operatorIndex++] = 0xD4637157937Afb544d7969C9F5D56a481A26f033;
        operators[operatorIndex++] = 0x4668d41D944B92f800965266D6382EF3F5C6B763;

        for (uint i = 0; i < stakingNodes.length; i++) {
            if (operators[i] == address(0)) continue;
            _buildDelegateTx(stakingNodes[i], operators[i], i);
        }
    }

    function _buildDelegateTx(address node, address operator, uint256 i) internal {
        address eigenOperatorAddr = operator;
        uint256 expiryTimestamp = IEigenOperator(eigenOperatorAddr).getCurrentTotpExpiryTimestamp();
        bytes32 salt = bytes32(expiryTimestamp);

        bytes memory delegateTxData = abi.encodeWithSelector(
            IStakingNode.delegate.selector,
            operator,
            ISignatureUtilsMixinTypes.SignatureWithExpiry({signature: "", expiry: expiryTimestamp}),
            salt
        );

        console.log("Node address:", node);
        console.log("Index:", i);
        console.log("Delegating to operator:", operator);
        console.log("EigenOperator:", eigenOperatorAddr);
        console.log("Expiry timestamp:", expiryTimestamp);
        console.log("Salt:", vm.toString(salt));
        console.log("Delegate transaction data:", vm.toString(abi.encodePacked(delegateTxData)));
    }
}