// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {AvsOperator} from "./AvsOperator.sol";
import {IAVSDirectory} from "./eigenlayer-interfaces/IAVSDirectory.sol";
import {IBLSApkRegistry} from "./eigenlayer-interfaces/IBLSApkRegistry.sol";
import {IDelegationManager} from "./eigenlayer-interfaces/IDelegationManager.sol";
import {IRegistryCoordinator} from "./eigenlayer-interfaces/IRegistryCoordinator.sol";
import {ISignatureUtils} from "./eigenlayer-interfaces/ISignatureUtils.sol";

/// @notice This contract was forked from the EtherFi Protocol.
/// @dev Original: https://github.com/etherfi-protocol/smart-contracts/blob/syko/feature/etherfi_avs_operator/src/EtherFiAvsOperatorsManager.sol
contract AvsOperatorsManager is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    IDelegationManager public delegationManager;
    UpgradeableBeacon public upgradableBeacon;

    uint256 public nextAvsOperatorId;

    mapping(uint256 => AvsOperator) public avsOperators;
    mapping(address => bool) public admins;

    IAVSDirectory public avsDirectory;

    error NotAdmin();
    error NotOperator();

    event CreatedAvsOperator(uint256 indexed id, address avsOperator);
    event DeregisteredOperator(uint256 indexed id, address avsServiceManager, bytes quorumNumbers);
    event ModifiedOperatorDetails(uint256 indexed id, IDelegationManager.OperatorDetails newOperatorDetails);
    event RegisteredAsOperator(uint256 indexed id, IDelegationManager.OperatorDetails detail);
    event RegisteredOperator(
        uint256 indexed id,
        address avsServiceManager,
        bytes quorumNumbers,
        string socket,
        IBLSApkRegistry.PubkeyRegistrationParams params,
        ISignatureUtils.SignatureWithSaltAndExpiry operatorSignature
    );
    event RegisteredBlsKeyAsDelegatedNodeOperator(
        uint256 indexed id,
        address avsServiceManager,
        bytes quorumNumbers,
        string socket,
        IBLSApkRegistry.PubkeyRegistrationParams params
    );
    event UpdatedAvsNodeRunner(uint256 indexed id, address avsNodeRunner);
    event UpdatedAvsWhitelist(uint256 indexed id, address avsServiceManager, bool isWhitelisted);
    event UpdatedEcdsaSigner(uint256 indexed id, address ecdsaSigner);
    event UpdatedOperatorMetadataURI(uint256 indexed id, string metadataURI);
    event UpdatedSocket(uint256 indexed id, address avsServiceManager, string socket);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _delegationManager, address _avsDirectory, address _avsOperatorImpl)
        external
        initializer
    {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();

        nextAvsOperatorId = 1;
        avsDirectory = IAVSDirectory(_avsDirectory);
        delegationManager = IDelegationManager(_delegationManager);
        upgradableBeacon = new UpgradeableBeacon(_avsOperatorImpl, msg.sender);
    }

    function initializeAvsDirectory(address _avsDirectory) external onlyOwner {
        avsDirectory = IAVSDirectory(_avsDirectory);
    }

    function createAvsOperator() external onlyOwner returns (uint256 _id) {
        _id = nextAvsOperatorId++;

        BeaconProxy proxy = new BeaconProxy(address(upgradableBeacon), "");
        avsOperators[_id] = AvsOperator(address(proxy));
        avsOperators[_id].initialize(address(this));

        emit CreatedAvsOperator(_id, address(avsOperators[_id]));

        return _id;
    }

    function upgradeAvsOperator(address _newImplementation) external onlyOwner {
        upgradableBeacon.upgradeTo(_newImplementation);
    }

    function registerBlsKeyAsDelegatedNodeOperator(
        uint256 _id,
        address _avsRegistryCoordinator,
        bytes calldata _quorumNumbers,
        string calldata _socket,
        IBLSApkRegistry.PubkeyRegistrationParams calldata _params
    ) external onlyOperator(_id) {
        avsOperators[_id].registerBlsKeyAsDelegatedNodeOperator(
            _avsRegistryCoordinator, _quorumNumbers, _socket, _params
        );

        emit RegisteredBlsKeyAsDelegatedNodeOperator(_id, _avsRegistryCoordinator, _quorumNumbers, _socket, _params);
    }

    // we got angry with {gnosis, etherscan} to deal with the tuple type
    function registerOperator(
        uint256 _id,
        address _avsRegistryCoordinator,
        bytes calldata _signature,
        bytes32 _salt,
        uint256 _expiry
    ) external onlyOperator(_id) {
        ISignatureUtils.SignatureWithSaltAndExpiry memory _operatorSignature =
            ISignatureUtils.SignatureWithSaltAndExpiry(_signature, _salt, _expiry);
        return registerOperator(_id, _avsRegistryCoordinator, _operatorSignature);
    }

    function registerOperator(
        uint256 _id,
        address _avsRegistryCoordinator,
        ISignatureUtils.SignatureWithSaltAndExpiry memory _operatorSignature
    ) public onlyOperator(_id) {
        AvsOperator.AvsInfo memory avsInfo = avsOperators[_id].getAvsInfo(_avsRegistryCoordinator);
        avsOperators[_id].registerOperator(_avsRegistryCoordinator, _operatorSignature);

        emit RegisteredOperator(
            _id, _avsRegistryCoordinator, avsInfo.quorumNumbers, avsInfo.socket, avsInfo.params, _operatorSignature
        );
    }

    function registerOperatorWithChurn(
        uint256 _id,
        address _avsRegistryCoordinator,
        IRegistryCoordinator.OperatorKickParam[] calldata _operatorKickParams,
        ISignatureUtils.SignatureWithSaltAndExpiry memory _churnApproverSignature,
        ISignatureUtils.SignatureWithSaltAndExpiry memory _operatorSignature
    ) external onlyOperator(_id) {
        AvsOperator.AvsInfo memory avsInfo = avsOperators[_id].getAvsInfo(_avsRegistryCoordinator);
        avsOperators[_id].registerOperatorWithChurn(
            _avsRegistryCoordinator, _operatorKickParams, _churnApproverSignature, _operatorSignature
        );

        emit RegisteredOperator(
            _id, _avsRegistryCoordinator, avsInfo.quorumNumbers, avsInfo.socket, avsInfo.params, _operatorSignature
        );
    }

    function deregisterOperator(uint256 _id, address _avsRegistryCoordinator, bytes calldata quorumNumbers)
        external
        onlyOperator(_id)
    {
        avsOperators[_id].deregisterOperator(_avsRegistryCoordinator, quorumNumbers);

        emit DeregisteredOperator(_id, _avsRegistryCoordinator, quorumNumbers);
    }

    function updateSocket(uint256 _id, address _avsRegistryCoordinator, string memory _socket)
        external
        onlyOperator(_id)
    {
        avsOperators[_id].updateSocket(_avsRegistryCoordinator, _socket);

        emit UpdatedSocket(_id, _avsRegistryCoordinator, _socket);
    }

    function registerAsOperator(
        uint256 _id,
        IDelegationManager.OperatorDetails calldata _detail,
        string calldata _metaDataURI
    ) external onlyOwner {
        avsOperators[_id].registerAsOperator(delegationManager, _detail, _metaDataURI);

        emit RegisteredAsOperator(_id, _detail);
    }

    function modifyOperatorDetails(uint256 _id, IDelegationManager.OperatorDetails calldata _newOperatorDetails)
        external
        onlyAdmin
    {
        avsOperators[_id].modifyOperatorDetails(delegationManager, _newOperatorDetails);

        emit ModifiedOperatorDetails(_id, _newOperatorDetails);
    }

    function updateOperatorMetadataURI(uint256 _id, string calldata _metadataURI) external onlyAdmin {
        avsOperators[_id].updateOperatorMetadataURI(delegationManager, _metadataURI);

        emit UpdatedOperatorMetadataURI(_id, _metadataURI);
    }

    function updateAvsNodeRunner(uint256 _id, address _avsNodeRunner) external onlyAdmin {
        avsOperators[_id].updateAvsNodeRunner(_avsNodeRunner);

        emit UpdatedAvsNodeRunner(_id, _avsNodeRunner);
    }

    function updateAvsWhitelist(uint256 _id, address _avsRegistryCoordinator, bool _isWhitelisted) external onlyAdmin {
        avsOperators[_id].updateAvsWhitelist(_avsRegistryCoordinator, _isWhitelisted);

        emit UpdatedAvsWhitelist(_id, _avsRegistryCoordinator, _isWhitelisted);
    }

    function updateEcdsaSigner(uint256 _id, address _ecdsaSigner) external onlyAdmin {
        avsOperators[_id].updateEcdsaSigner(_ecdsaSigner);

        emit UpdatedEcdsaSigner(_id, _ecdsaSigner);
    }

    function updateAdmin(address _address, bool _isAdmin) external onlyOwner {
        admins[_address] = _isAdmin;
    }

    function calculateOperatorAVSRegistrationDigestHash(
        uint256 _id,
        address _avsServiceManager,
        bytes32 _salt,
        uint256 _expiry
    ) external view returns (bytes32) {
        address _operator = address(avsOperators[_id]);
        return avsDirectory.calculateOperatorAVSRegistrationDigestHash(_operator, _avsServiceManager, _salt, _expiry);
    }

    function avsOperatorStatus(uint256 _id, address _avsServiceManager)
        external
        view
        returns (IAVSDirectory.OperatorAVSRegistrationStatus)
    {
        return avsDirectory.avsOperatorStatus(_avsServiceManager, address(avsOperators[_id]));
    }

    function getAvsInfo(uint256 _id, address _avsRegistryCoordinator)
        external
        view
        returns (AvsOperator.AvsInfo memory)
    {
        return avsOperators[_id].getAvsInfo(_avsRegistryCoordinator);
    }

    function isAvsWhitelisted(uint256 _id, address _avsRegistryCoordinator) external view returns (bool) {
        return avsOperators[_id].isAvsWhitelisted(_avsRegistryCoordinator);
    }

    function isAvsRegistered(uint256 _id, address _avsRegistryCoordinator) external view returns (bool) {
        return avsOperators[_id].isAvsRegistered(_avsRegistryCoordinator);
    }

    function isRegisteredBlsKey(
        uint256 _id,
        address _avsRegistryCoordinator,
        bytes calldata _quorumNumbers,
        string calldata _socket,
        IBLSApkRegistry.PubkeyRegistrationParams calldata _params
    ) external view returns (bool) {
        return avsOperators[_id].isRegisteredBlsKey(_avsRegistryCoordinator, _quorumNumbers, _socket, _params);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function _onlyOperator(uint256 _id) internal view {
        if (msg.sender != avsOperators[_id].avsNodeRunner() && !admins[msg.sender] && msg.sender != owner()) {
            revert NotOperator();
        }
    }

    modifier onlyOperator(uint256 _id) {
        _onlyOperator(_id);
        _;
    }

    function _onlyAdmin() internal view {
        if (!admins[msg.sender] && msg.sender != owner()) revert NotAdmin();
    }

    modifier onlyAdmin() {
        _onlyAdmin();
        _;
    }
}
