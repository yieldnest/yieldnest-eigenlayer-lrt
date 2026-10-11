// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { UpgradeableBeacon } from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import { IRewardsCoordinator } from "@eigenlayer/src/contracts/interfaces/IRewardsCoordinator.sol";

interface IEigenServiceManager {
    /// @dev Invalid AVS
    error InvalidAVS();
    /// @dev Invalid operator set ids
    error InvalidOperatorSetIds();
    /// @dev Invalid operator
    error InvalidOperator();
    /// @dev Operator already registered
    error AlreadyRegisteredOperator();
    /// @dev Invalid redistribution recipient
    error InvalidRedistributionRecipient();
    /// @dev Zero address
    error ZeroAddress();
    /// @dev Operator set already created
    error OperatorSetAlreadyCreated();
    /// @dev Operator doesn't exist
    error OperatorDoesntExist();
    /// @dev Min magnitude not met
    error MinMagnitudeNotMet();
    /// @dev Invalid decimals
    error InvalidDecimals();
    /// @dev Min share not met
    error MinShareNotMet();
    /// @dev Zero slash
    error ZeroSlash();
    /// @dev Slash share too small
    error SlashShareTooSmall();

    /// @dev Operator registered
    event OperatorRegistered(
        address indexed operator, address indexed eigenOperator, address indexed avs, uint32 operatorSetId
    );
    /// @dev Emitted on slash
    event Slash(address indexed agent, address indexed recipient, uint256 slashShare, uint48 timestamp);
    /// @dev Strategy registered
    event StrategyRegistered(address indexed strategy, address indexed operator);
    /// @dev Epochs between distributions set
    event EpochsBetweenDistributionsSet(uint32 epochsBetweenDistributions);
    /// @dev Min reward amount set
    event MinRewardAmountSet(uint256 minRewardAmount);
    /// @dev Distributed rewards
    event DistributedRewards(address indexed strategy, address indexed token, uint256 amount);

    /// @dev EigenServiceManager storage
    /// @param eigen Eigen addresses
    /// @param oracle Oracle address
    /// @param eigenOperatorInstance Eigen operator instance
    /// @param epochsBetweenDistributions Epochs between distributions
    /// @param nextOperatorId Next operator id
    /// @param pendingRewards Pending rewards
    /// @param eigenOperatorToOperator Mapping from eigen operator to operator
    struct EigenServiceManagerStorage {
        EigenAddresses eigen;
        address oracle;
        address eigenOperatorInstance;
        address[] redistributionRecipients;
        uint32 epochsBetweenDistributions;
        uint32 nextOperatorId;
        mapping(address => uint256) pendingRewardsByToken;
        mapping(address => CachedOperatorData) operators;
        mapping(address => address) eigenOperatorToOperator;
    }

    /// @dev Cached operator data
    /// @param eigenOperator Eigen operator address
    /// @param strategy Strategy address
    /// @param createdAtEpoch Epoch at which the operator was created
    /// @param operatorSetId Operator set id
    /// @param pendingRewards Pending rewards
    struct CachedOperatorData {
        address eigenOperator;
        address strategy;
        uint32 createdAtEpoch;
        uint32 operatorSetId;
        mapping(address => uint256) pendingRewards;
        mapping(address => uint32) lastDistributionEpoch;
    }

    /// @dev Eigen addresses
    /// @param allocationManager Allocation manager address
    /// @param delegationManager Delegation manager address
    /// @param strategyManager Strategy manager address
    /// @param rewardsCoordinator Rewards coordinator address
    struct EigenAddresses {
        address allocationManager;
        address delegationManager;
        address strategyManager;
        address rewardsCoordinator;
    }

    /// @notice Initialize the EigenServiceManager
    /// @param _accessControl Access control contract
    /// @param _addresses Eigen addresses
    /// @param _oracle Oracle contract
    /// @param _rewardDuration Reward duration
    function initialize(
        address _accessControl,
        EigenAddresses memory _addresses,
        address _oracle,
        uint32 _rewardDuration
    ) external;

    /**
     * @notice Creates a new rewards submission to the EigenLayer RewardsCoordinator contract, to be split amongst the
     * set of stakers delegated to operators who are registered to this `avs`
     * @param rewardsSubmissions The rewards submissions being created
     * @dev Only callable by the permissioned rewardsInitiator address
     * @dev The duration of the `rewardsSubmission` cannot exceed `MAX_REWARDS_DURATION`
     * @dev The tokens are sent to the `RewardsCoordinator` contract
     * @dev Strategies must be in ascending order of addresses to check for duplicates
     * @dev This function will revert if the `rewardsSubmission` is malformed,
     * e.g. if the `strategies` and `weights` arrays are of non-equal lengths
     * @dev This function may fail to execute with a large number of submissions due to gas limits. Use a
     * smaller array of submissions if necessary.
     */

    /**
     * @notice Distributes rewards to the operator
     * @param _operator The operator to distribute rewards to
     * @param _token The token to distribute rewards for
     */
    function distributeRewards(address _operator, address _token) external;

    /**
     * @notice Returns the coverage for an operator
     * @param operator The operator to get the coverage for
     * @return The coverage of the operator
     */
    function coverage(address operator) external view returns (uint256);

    /**
     * @notice Registers an operator to the AVS, called by the Allocation Manager contract (access control set for the allocation manager).
     * @param _operator The operator to register
     * @param _avs The AVS to register the operator to
     * @param _operatorSetIds The operator set ids to register the operator to
     * @param _data Additional data
     */
    function registerOperator(address _operator, address _avs, uint32[] calldata _operatorSetIds, bytes calldata _data)
        external;

    /**
     * @notice Registers a strategy to the AVS
     * @param _strategy The strategy to register
     * @param _operator The operator to register the strategy to
     * @param _restaker The restaker to register the strategy to
     * @param _operatorMetadata The metadata for the operator
     * @return _operatorSetId The operator set id
     */
    function registerStrategy(address _strategy, address _operator, address _restaker, string memory _operatorMetadata)
        external
        returns (uint32 _operatorSetId);

    /**
     * @notice Slashes an operator
     * @param _operator The operator to slash
     * @param _recipient The recipient of the slashed collateral
     * @param _slashShare The share of the slashable collateral to slash
     * @param _timestamp The timestamp of the slash (unused for eigenlayer)
     */
    function slash(address _operator, address _recipient, uint256 _slashShare, uint48 _timestamp) external;

    /**
     * @notice Allocates the operator set, is public and can be called permissionless. We would have allocated on registerStrategy but it needs to wait at least a block.
     * @param _operator Operator address
     */
    function allocate(address _operator) external;

    /**
     * @notice Returns the slashable collateral for an operator
     * @param operator The operator to get the slashable collateral for
     * @param timestamp The timestamp to get the slashable collateral for (unused for eigenlayer)
     * @return The slashable collateral of the operator
     */
    function slashableCollateral(address operator, uint48 timestamp) external view returns (uint256);

    /**
     * @notice Sets the epochs between distributions
     * @param _epochsBetweenDistributions The epochs between distributions
     */
    function setEpochsBetweenDistributions(uint32 _epochsBetweenDistributions) external;

    /**
     * @notice Updates the AVS metadata URI
     * @param _metadataURI The new metadata URI
     */
    function updateAVSMetadataURI(string calldata _metadataURI) external;

    /**
     * @notice Upgrades the eigen operator implementation
     * @param _newImplementation The new implementation
     */
    function upgradeEigenOperatorImplementation(address _newImplementation) external;

    /**
     * @notice Returns the eigen addresses
     * @return The eigen addresses
     */
    function eigenAddresses() external view returns (EigenAddresses memory);

    /**
     * @notice Returns the operator to strategy mapping
     * @return The operator to strategy mapping
     */
    function operatorToStrategy(address operator) external view returns (address);

    /**
     * @notice Returns the operator set id for an operator
     * @param operator The operator to get the operator set id for
     * @return The operator set id of the operator
     */
    function operatorSetId(address operator) external view returns (uint32);

    /**
     * @notice Returns the epochs between distributions
     * @return The epochs between distributions
     */
    function epochsBetweenDistributions() external view returns (uint32);

    /**
     * @notice Returns the created at epoch for an operator
     * @param operator The operator to get the created at epoch for
     * @return The created at epoch of the operator
     */
    function createdAtEpoch(address operator) external view returns (uint32);

    /**
     * @notice Returns the calculation interval seconds
     * @return The calculation interval seconds
     */
    function calculationIntervalSeconds() external view returns (uint256);

    /**
     * @notice Returns the pending rewards for an operator
     * @param _strategy The strategy to get the pending rewards for
     * @param _token The token to get the pending rewards for
     * @return The pending rewards of the strategy
     */
    function pendingRewards(address _strategy, address _token) external view returns (uint256);

    /**
     * @notice Returns the eigen operator for an operator
     * @param _operator The operator to get the eigen operator for
     * @return The eigen operator of the operator
     */
    function getEigenOperator(address _operator) external view returns (address);
}