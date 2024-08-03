// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {IBeacon} from "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {IBLSApkRegistry} from "./eigenlayer-interfaces/IBLSApkRegistry.sol";
import {IDelegationManager} from "./eigenlayer-interfaces/IDelegationManager.sol";
import {IRegistryCoordinator} from "./eigenlayer-interfaces/IRegistryCoordinator.sol";
import {ISignatureUtils} from "./eigenlayer-interfaces/ISignatureUtils.sol";
import {BN254} from "./eigenlayer-libraries/BN254.sol";

/// @notice This contract was forked from the EtherFi Protocol.
/// @dev Original: https://github.com/etherfi-protocol/smart-contracts/blob/syko/feature/etherfi_avs_operator/src/EtherFiAvsOperator.sol
contract AvsOperator is IERC1271, IBeacon {
    struct AvsInfo {
        bool isWhitelisted;
        bytes quorumNumbers;
        string socket;
        IBLSApkRegistry.PubkeyRegistrationParams params;
        bool isRegistered;
    }

    mapping(address => AvsInfo) public avsInfos;

    address public avsOperatorsManager;
    address public ecdsaSigner;
    address public avsNodeRunner;

    error AlreadyInitialized();
    error AvsNotWhitelisted();
    error AvsNotRegistered();
    error AvsAlreadyRegistered();
    error InvalidAddress();
    error NotManager();

    function initialize(address _avsOperatorsManager) external {
        if (avsOperatorsManager != address(0)) revert AlreadyInitialized();
        if (_avsOperatorsManager == address(0)) revert InvalidAddress();
        avsOperatorsManager = _avsOperatorsManager;
    }

    function registerAsOperator(
        IDelegationManager _delegationManager,
        IDelegationManager.OperatorDetails calldata _detail,
        string calldata _metaDataURI
    ) external managerOnly {
        _delegationManager.registerAsOperator(_detail, _metaDataURI);
    }

    function modifyOperatorDetails(
        IDelegationManager _delegationManager,
        IDelegationManager.OperatorDetails calldata _newOperatorDetails
    ) external managerOnly {
        _delegationManager.modifyOperatorDetails(_newOperatorDetails);
    }

    function updateOperatorMetadataURI(IDelegationManager _delegationManager, string calldata _metadataURI)
        external
        managerOnly
    {
        _delegationManager.updateOperatorMetadataURI(_metadataURI);
    }

    function updateSocket(address _avsRegistryCoordinator, string memory _socket) external {
        if (!isAvsWhitelisted(_avsRegistryCoordinator)) revert AvsNotWhitelisted();
        if (!isAvsRegistered(_avsRegistryCoordinator)) revert AvsNotRegistered();

        IRegistryCoordinator(_avsRegistryCoordinator).updateSocket(_socket);
        avsInfos[_avsRegistryCoordinator].socket = _socket;
    }

    function registerBlsKeyAsDelegatedNodeOperator(
        address _avsRegistryCoordinator,
        bytes calldata _quorumNumbers,
        string calldata _socket,
        IBLSApkRegistry.PubkeyRegistrationParams calldata _params
    ) external managerOnly {
        if (!isAvsWhitelisted(_avsRegistryCoordinator)) revert AvsNotWhitelisted();
        if (isAvsRegistered(_avsRegistryCoordinator)) revert AvsAlreadyRegistered();
        require(
            verifyBlsKey(_avsRegistryCoordinator, _params),
            "BLSApkRegistry.registerBLSPublicKey: either the G1 signature is wrong, or G1 and G2 private key do not match"
        );

        avsInfos[_avsRegistryCoordinator].quorumNumbers = _quorumNumbers;
        avsInfos[_avsRegistryCoordinator].socket = _socket;
        avsInfos[_avsRegistryCoordinator].params = _params;
    }

    function registerOperator(
        address _avsRegistryCoordinator,
        ISignatureUtils.SignatureWithSaltAndExpiry memory _operatorSignature
    ) external managerOnly {
        if (!isAvsWhitelisted(_avsRegistryCoordinator)) revert AvsNotWhitelisted();
        if (isAvsRegistered(_avsRegistryCoordinator)) revert AvsAlreadyRegistered();

        avsInfos[_avsRegistryCoordinator].isRegistered = true;

        IRegistryCoordinator(_avsRegistryCoordinator).registerOperator(
            avsInfos[_avsRegistryCoordinator].quorumNumbers,
            avsInfos[_avsRegistryCoordinator].socket,
            avsInfos[_avsRegistryCoordinator].params,
            _operatorSignature
        );
    }

    function registerOperatorWithChurn(
        address _avsRegistryCoordinator,
        IRegistryCoordinator.OperatorKickParam[] calldata _operatorKickParams,
        ISignatureUtils.SignatureWithSaltAndExpiry memory _churnApproverSignature,
        ISignatureUtils.SignatureWithSaltAndExpiry memory _operatorSignature
    ) external managerOnly {
        if (!isAvsWhitelisted(_avsRegistryCoordinator)) revert AvsNotWhitelisted();
        if (isAvsRegistered(_avsRegistryCoordinator)) revert AvsAlreadyRegistered();

        IRegistryCoordinator(_avsRegistryCoordinator).registerOperatorWithChurn(
            avsInfos[_avsRegistryCoordinator].quorumNumbers,
            avsInfos[_avsRegistryCoordinator].socket,
            avsInfos[_avsRegistryCoordinator].params,
            _operatorKickParams,
            _churnApproverSignature,
            _operatorSignature
        );
    }

    function deregisterOperator(address _avsRegistryCoordinator, bytes calldata quorumNumbers) external managerOnly {
        delete avsInfos[_avsRegistryCoordinator];

        IRegistryCoordinator(_avsRegistryCoordinator).deregisterOperator(quorumNumbers);
    }

    function updateAvsNodeRunner(address _avsNodeRunner) external managerOnly {
        avsNodeRunner = _avsNodeRunner;
    }

    function updateAvsWhitelist(address _avsRegistryCoordinator, bool _isWhitelisted) external managerOnly {
        avsInfos[_avsRegistryCoordinator].isWhitelisted = _isWhitelisted;
    }

    function updateEcdsaSigner(address _ecdsaSigner) external managerOnly {
        if (_ecdsaSigner == address(0)) revert InvalidAddress();
        ecdsaSigner = _ecdsaSigner;
    }

    function getAvsInfo(address _avsRegistryCoordinator) external view returns (AvsInfo memory) {
        return avsInfos[_avsRegistryCoordinator];
    }

    function isValidSignature(bytes32 _digestHash, bytes memory _signature)
        public
        view
        override
        returns (bytes4 magicValue)
    {
        (address recovered,,) = ECDSA.tryRecover(_digestHash, _signature);
        return recovered == ecdsaSigner ? this.isValidSignature.selector : bytes4(0xffffffff);
    }

    function isAvsWhitelisted(address _avsRegistryCoordinator) public view returns (bool) {
        return avsInfos[_avsRegistryCoordinator].isWhitelisted;
    }

    function isAvsRegistered(address _avsRegistryCoordinator) public view returns (bool) {
        return avsInfos[_avsRegistryCoordinator].isRegistered;
    }

    function isRegisteredBlsKey(
        address _avsRegistryCoordinator,
        bytes calldata _quorumNumbers,
        string calldata _socket,
        IBLSApkRegistry.PubkeyRegistrationParams calldata _params
    ) public view returns (bool) {
        AvsInfo memory avsInfo = avsInfos[_avsRegistryCoordinator];
        bytes32 digestHash1 = keccak256(abi.encode(_avsRegistryCoordinator, _quorumNumbers, _socket, _params));
        bytes32 digestHash2 =
            keccak256(abi.encode(_avsRegistryCoordinator, avsInfo.quorumNumbers, avsInfo.socket, avsInfo.params));

        return digestHash1 == digestHash2;
    }

    function verifyBlsKeyAgainstHash(
        BN254.G1Point memory pubkeyRegistrationMessageHash,
        IBLSApkRegistry.PubkeyRegistrationParams memory params
    ) public view returns (bool) {
        // gamma = h(sigma, P, P', H(m))
        uint256 gamma = uint256(
            keccak256(
                abi.encodePacked(
                    params.pubkeyRegistrationSignature.X,
                    params.pubkeyRegistrationSignature.Y,
                    params.pubkeyG1.X,
                    params.pubkeyG1.Y,
                    params.pubkeyG2.X,
                    params.pubkeyG2.Y,
                    pubkeyRegistrationMessageHash.X,
                    pubkeyRegistrationMessageHash.Y
                )
            )
        ) % BN254.FR_MODULUS;

        // e(sigma + P * gamma, [-1]_2) = e(H(m) + [1]_1 * gamma, P')
        return BN254.pairing(
            BN254.plus(params.pubkeyRegistrationSignature, BN254.scalar_mul(params.pubkeyG1, gamma)),
            BN254.negGeneratorG2(),
            BN254.plus(pubkeyRegistrationMessageHash, BN254.scalar_mul(BN254.generatorG1(), gamma)),
            params.pubkeyG2
        );
    }

    function verifyBlsKey(address registryCoordinator, IBLSApkRegistry.PubkeyRegistrationParams memory params)
        public
        view
        returns (bool)
    {
        BN254.G1Point memory pubkeyRegistrationMessageHash =
            IRegistryCoordinator(registryCoordinator).pubkeyRegistrationMessageHash(address(this));

        return verifyBlsKeyAgainstHash(pubkeyRegistrationMessageHash, params);
    }

    function implementation() external view returns (address) {
        bytes32 slot = bytes32(uint256(keccak256("eip1967.proxy.beacon")) - 1);
        address implementationVariable;
        assembly {
            implementationVariable := sload(slot)
        }

        IBeacon beacon = IBeacon(implementationVariable);
        return beacon.implementation();
    }

    modifier managerOnly() {
        if (msg.sender != avsOperatorsManager) revert NotManager();
        _;
    }
}
