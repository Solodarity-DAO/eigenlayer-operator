// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IDelegationManager} from "@eigenlayer/interfaces/IDelegationManager.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {AvsOperator} from "./AvsOperator.sol";

/// @notice This contract was forked from the EtherFi Protocol.
/// @dev Original: https://github.com/etherfi-protocol/smart-contracts/blob/syko/feature/etherfi_avs_operator/src/EtherFiAvsOperatorsManager.sol
contract AvsOperatorsManager is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    IDelegationManager public delegationManager;
    UpgradeableBeacon public upgradableBeacon;

    uint256 public nextAvsOperatorId;

    mapping(uint256 => AvsOperator) public avsOperators;
    mapping(address => bool) public admins;

    error NotAdmin();

    event CreatedAvsOperator(uint256 indexed id, address avsOperator);
    event ModifiedOperatorDetails(uint256 indexed id, IDelegationManager.OperatorDetails newOperatorDetails);
    event RegisteredAsOperator(uint256 indexed id, IDelegationManager.OperatorDetails detail);
    event UpdatedEcdsaSigner(uint256 indexed id, address ecdsaSigner);
    event UpdatedOperatorMetadataURI(uint256 indexed id, string metadataURI);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize the contract with the address of the AVS Operator implementation.
     * @param _avsOperatorImpl The address of the AVS Operator implementation contract.
     */
    function initialize(address _delegationManager, address _avsOperatorImpl) external initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();

        nextAvsOperatorId = 1;
        delegationManager = IDelegationManager(_delegationManager);
        upgradableBeacon = new UpgradeableBeacon(_avsOperatorImpl, msg.sender);
    }

    /**
     * @notice Create a new AVS Operator.
     * @return _id The ID of the newly created AVS Operator.
     */
    function createAvsOperator() external onlyOwner returns (uint256 _id) {
        _id = nextAvsOperatorId++;

        BeaconProxy proxy = new BeaconProxy(address(upgradableBeacon), "");
        avsOperators[_id] = AvsOperator(address(proxy));
        avsOperators[_id].initialize(address(this));

        emit CreatedAvsOperator(_id, address(avsOperators[_id]));

        return _id;
    }

    /**
     * @notice Upgrade the AVS Operator implementation to a new address.
     * @param _newImplementation The address of the new implementation contract.
     */
    function upgradeAvsOperator(address _newImplementation) external onlyOwner {
        upgradableBeacon.upgradeTo(_newImplementation);
    }

    /**
     * @notice Registers the operator with the given details and metadata URI.
     * @dev Can only be called by the contract owner.
     * @param _id The identifier for the operator.
     * @param _detail The operator's details.
     * @param _metaDataURI The URI pointing to the operator's metadata.
     */
    function registerAsOperator(
        uint256 _id,
        IDelegationManager.OperatorDetails calldata _detail,
        string calldata _metaDataURI
    ) external onlyOwner {
        avsOperators[_id].registerAsOperator(delegationManager, _detail, _metaDataURI);

        emit RegisteredAsOperator(_id, _detail);
    }

    /**
     * @notice Modifies the operator details for the given operator ID.
     * @dev Can only be called by an admin.
     * @param _id The identifier for the operator.
     * @param _newOperatorDetails The new details for the operator.
     */
    function modifyOperatorDetails(uint256 _id, IDelegationManager.OperatorDetails calldata _newOperatorDetails)
        external
        onlyAdmin
    {
        avsOperators[_id].modifyOperatorDetails(delegationManager, _newOperatorDetails);

        emit ModifiedOperatorDetails(_id, _newOperatorDetails);
    }

    /**
     * @notice Updates the metadata URI for the given operator ID.
     * @dev Can only be called by an admin.
     * @param _id The identifier for the operator.
     * @param _metadataURI The new metadata URI for the operator.
     */
    function updateOperatorMetadataURI(uint256 _id, string calldata _metadataURI) external onlyAdmin {
        avsOperators[_id].updateOperatorMetadataURI(delegationManager, _metadataURI);

        emit UpdatedOperatorMetadataURI(_id, _metadataURI);
    }

    /**
     * @notice Update the ECDSA signer address for a specific AVS Operator.
     * @param _id The ID of the AVS Operator.
     * @param _ecdsaSigner The new ECDSA signer address.
     */
    function updateEcdsaSigner(uint256 _id, address _ecdsaSigner) external onlyAdmin {
        avsOperators[_id].updateEcdsaSigner(_ecdsaSigner);

        emit UpdatedEcdsaSigner(_id, _ecdsaSigner);
    }

    /**
     * @notice Update the admin status of an address.
     * @param _address The address to update.
     * @param _isAdmin Whether the address should be an admin or not.
     */
    function updateAdmin(address _address, bool _isAdmin) external onlyOwner {
        admins[_address] = _isAdmin;
    }

    /**
     * @dev Authorize the upgrade of the contract. Only the owner can authorize upgrades.
     * @param newImplementation The address of the new implementation contract.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /**
     * @dev Internal function to check if the caller is an admin.
     */
    function _onlyAdmin() internal view {
        if (!admins[msg.sender] && msg.sender != owner()) revert NotAdmin();
    }

    /**
     * @dev Modifier to allow only admins to call a function.
     */
    modifier onlyAdmin() {
        _onlyAdmin();
        _;
    }
}
