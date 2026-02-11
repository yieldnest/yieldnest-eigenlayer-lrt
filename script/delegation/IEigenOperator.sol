// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

interface IEigenOperator {
    /// @dev Error thrown when the caller is not the service manager
    error NotServiceManager();
    /// @dev Error thrown when the caller is not the operator
    error NotOperator();
    /// @dev Error thrown when the operator is already allocated to a strategy
    error AlreadyAllocated();
    /// @dev Error thrown when the caller is not the restaker
    error NotRestaker();
    /// @dev Error thrown when the operator is already registered
    error AlreadyRegistered();
    /// @dev Error thrown when the staker is the zero address
    error ZeroAddress();

    /// @dev EigenOperator storage
    /// @param serviceManager EigenServiceManager address
    /// @param operator Eigen operator address
    /// @param allocationManager EigenCloud Allocation manager address
    /// @param delegationManager EigenCloud Delegation manager address
    /// @param rewardsCoordinator EigenCloud Rewards coordinator address
    struct EigenOperatorStorage {
        address serviceManager;
        address operator;
        address allocationManager;
        address delegationManager;
        address rewardsCoordinator;
        address restaker;
        uint32 totpPeriod;
        mapping(bytes32 => bool) allowlistedDigests;
    }

    /// @notice Initialize the EigenOperator
    /// @param _serviceManager EigenServiceManager address
    /// @param _operator Eigen operator address
    /// @param _metadata Metadata URI
    function initialize(address _serviceManager, address _operator, string calldata _metadata) external;

    /// @notice Register an operator set to the service manager
    /// @param _operatorSetId Operator set id
    function registerOperatorSetToServiceManager(uint32 _operatorSetId, address _staker) external;

    /// @notice Update the operator metadata URI
    /// @param _metadataURI The new metadata URI
    function updateOperatorMetadataURI(string calldata _metadataURI) external;

    /// @notice Allocate the operator set to the strategy, called by service manager.
    /// @param _operatorSetId Operator set id
    /// @param _strategy Strategy address
    function allocate(uint32 _operatorSetId, address _strategy) external;

    /// @notice Advance the TOTP
    function advanceTotp() external;

    /// @notice Get the service manager
    /// @return The service manager address
    function eigenServiceManager() external view returns (address);

    /**
     * @notice Implements the IERC1271 interface to validate signatures
     * @dev In this implementation, we check if the digest hash is directly allowlisted
     * @param digest The digest hash containing encoded delegation information
     * @return magicValue Returns the ERC1271 magic value if valid, or 0xffffffff if invalid
     */
    function isValidSignature(bytes32 digest, bytes memory signature) external view returns (bytes4 magicValue);

    /// @notice Get the operator
    /// @return The operator or borrower address in the cap system
    function operator() external view returns (address);

    /// @notice Get the current TOTP
    /// @return The current TOTP
    function currentTotp() external view returns (uint256);

    /// @notice Get the current TOTP expiry timestamp
    /// @return The current TOTP expiry timestamp
    function getCurrentTotpExpiryTimestamp() external view returns (uint256);

    /// @notice Calculate the TOTP digest hash
    /// @param _staker The staker address
    /// @param _operator The operator address
    /// @return The TOTP digest hash
    function calculateTotpDigestHash(address _staker, address _operator) external view returns (bytes32);

    /// @notice Get the restaker
    /// @return The restaker address
    function restaker() external view returns (address);
}