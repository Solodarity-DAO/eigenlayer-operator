// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
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
contract AvsOperatorsManager is Initializable, OwnableUpgradeable, PausableUpgradeable, UUPSUpgradeable {
    IDelegationManager public delegationManager;
    UpgradeableBeacon public upgradableBeacon;

    uint256 public nextAvsOperatorId;

    mapping(uint256 => AvsOperator) public avsOperators;
    mapping(address => bool) public admins;

    IAVSDirectory public avsDirectory;

    mapping(address => bool) public pausers;
    // operator -> targetAddress -> selector -> allowed
    mapping(uint256 => mapping(address => mapping(bytes4 => bool))) public allowedOperatorCalls;

    error InvalidOperatorCall();
    error NotAdmin();
    error NotOperator();

    event AdminUpdated(address indexed admin, bool isAdmin);
    event AllowedOperatorCallsUpdated(
        uint256 indexed id, address indexed target, bytes4 indexed selector, bool allowed
    );
    event CreatedAvsOperator(uint256 indexed id, address avsOperator);
    event DeregisteredOperator(uint256 indexed id, address avsServiceManager, bytes quorumNumbers);
    event ForwardedOperatorCall(
        uint256 indexed id, address indexed target, bytes4 indexed selector, bytes data, address sender
    );
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
        __Pausable_init();
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();

        nextAvsOperatorId = 1;
        avsDirectory = IAVSDirectory(_avsDirectory);
        delegationManager = IDelegationManager(_delegationManager);
        upgradableBeacon = new UpgradeableBeacon(_avsOperatorImpl, address(this));
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

    //--------------------------------------------------------------------------------------
    //---------------------------------  Eigenlayer Core  ----------------------------------
    //--------------------------------------------------------------------------------------

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

    //--------------------------------------------------------------------------------------
    //--------------------------------------  Admin  ---------------------------------------
    //--------------------------------------------------------------------------------------

    // specify which calls an node runner can make against which target contracts through the operator contract
    function updateAllowedOperatorCalls(uint256 _operatorId, address _target, bytes4 _selector, bool _allowed)
        external
        onlyAdmin
    {
        allowedOperatorCalls[_operatorId][_target][_selector] = _allowed;
        emit AllowedOperatorCallsUpdated(_operatorId, _target, _selector, _allowed);
    }

    function updateAvsNodeRunner(uint256 _id, address _avsNodeRunner) external onlyAdmin {
        avsOperators[_id].updateAvsNodeRunner(_avsNodeRunner);
        emit UpdatedAvsNodeRunner(_id, _avsNodeRunner);
    }

    function updateEcdsaSigner(uint256 _id, address _ecdsaSigner) external onlyAdmin {
        avsOperators[_id].updateEcdsaSigner(_ecdsaSigner);
        emit UpdatedEcdsaSigner(_id, _ecdsaSigner);
    }

    function updateAdmin(address _address, bool _isAdmin) external onlyOwner {
        admins[_address] = _isAdmin;
        emit AdminUpdated(_address, _isAdmin);
    }

    //--------------------------------------------------------------------------------------
    //-----------------------------------  AVS Actions  ------------------------------------
    //--------------------------------------------------------------------------------------

    // Forward an arbitrary call to be run by the operator conract.
    // That operator must be approved for the specific method and target
    function forwardOperatorCall(uint256 _id, address _target, bytes4 _selector, bytes calldata _args)
        external
        onlyOperator(_id)
    {
        _forwardOperatorCall(_id, _target, _selector, _args);
    }

    // alternative version where you just pass raw input. Not sure which will end up being more convenient
    function forwardOperatorCall(uint256 _id, address _target, bytes calldata _input) external onlyOperator(_id) {
        if (_input.length < 4) revert InvalidOperatorCall();

        bytes4 _selector = bytes4(_input[:4]);
        bytes calldata _args = _input[4:];

        _forwardOperatorCall(_id, _target, _selector, _args);
    }

    function _forwardOperatorCall(uint256 _id, address _target, bytes4 _selector, bytes calldata _args) private {
        if (!isValidOperatorCall(_id, _target, _selector, _args)) revert InvalidOperatorCall();

        avsOperators[_id].forwardCall(_target, abi.encodePacked(_selector, _args));
        emit ForwardedOperatorCall(_id, _target, _selector, _args, msg.sender);
    }

    // Forward an arbitrary call to be run by the operator conract. Admins can ignore the call whitelist
    function adminForwardCall(uint256 _id, address _target, bytes4 _selector, bytes calldata _args)
        external
        onlyAdmin
    {
        avsOperators[_id].forwardCall(_target, abi.encodePacked(_selector, _args));
        emit ForwardedOperatorCall(_id, _target, _selector, _args, msg.sender);
    }

    function isValidOperatorCall(uint256 _id, address _target, bytes4 _selector, bytes calldata)
        public
        view
        returns (bool)
    {
        // ensure this method is allowed by this operator on target contract
        if (!allowedOperatorCalls[_id][_target][_selector]) return false;

        // could add other custom logic here that inspects payload or other data

        return true;
    }

    //--------------------------------------------------------------------------------------
    //-------------------------------  View Functions  -------------------------------------
    //--------------------------------------------------------------------------------------

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

    function avsNodeRunner(uint256 _id) external view returns (address) {
        return avsOperators[_id].avsNodeRunner();
    }

    function ecdsaSigner(uint256 _id) external view returns (address) {
        return avsOperators[_id].ecdsaSigner();
    }

    function operatorDetails(uint256 _id) external view returns (IDelegationManager.OperatorDetails memory) {
        return delegationManager.operatorDetails(address(avsOperators[_id]));
    }

    // DEPRECATED
    function getAvsInfo(uint256 _id, address _avsRegistryCoordinator)
        external
        view
        returns (AvsOperator.AvsInfo memory)
    {
        return avsOperators[_id].getAvsInfo(_avsRegistryCoordinator);
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
