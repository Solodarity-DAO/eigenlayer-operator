// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "./AvsOperator.sol";

/// @notice This contract was forked from the EtherFi Protocol.
/// @dev Original: https://github.com/etherfi-protocol/smart-contracts/blob/syko/feature/etherfi_avs_operator/src/EtherFiAvsOperatorsManager.sol
contract AvsOperatorsManager is Initializable, OwnableUpgradeable, PausableUpgradeable, UUPSUpgradeable {
    UpgradeableBeacon public upgradableBeacon;
    uint256 public nextAvsOperatorId;
    mapping(uint256 => AvsOperator) public avsOperators;
    mapping(address => bool) public admins;

    error NotAdmin();

    event CreatedAvsOperator(uint256 indexed id, address avsOperator);
    event UpdatedEcdsaSigner(uint256 indexed id, address ecdsaSigner);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize the contract with the address of the AVS Operator implementation.
     * @param _avsOperatorImpl The address of the AVS Operator implementation contract.
     */
    function initialize(address _avsOperatorImpl) external initializer {
        __Pausable_init();
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();

        nextAvsOperatorId = 1;
        upgradableBeacon = new UpgradeableBeacon(_avsOperatorImpl, msg.sender);
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
