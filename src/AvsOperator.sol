// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {IBeacon} from "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {IBLSApkRegistry} from "./eigenlayer-interfaces/IBLSApkRegistry.sol";
import {IDelegationManager} from "./eigenlayer-interfaces/IDelegationManager.sol";
import {IRegistryCoordinator} from "./eigenlayer-interfaces/IRegistryCoordinator.sol";
import {ISignatureUtils} from "./eigenlayer-interfaces/ISignatureUtils.sol";
import {BN254} from "./eigenlayer-libraries/BN254.sol";

/// @notice This contract was forked from the EtherFi Protocol.
/// @dev Original: https://github.com/etherfi-protocol/avs-smart-contracts/blob/master/src/AvsOperator.sol
contract AvsOperator is IERC1271, IBeacon {
    // DEPRECATED
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

    //--------------------------------------------------------------------------------------
    //----------------------------------  Admin  -------------------------------------------
    //
    function initialize(address _avsOperatorsManager) external {
        if (avsOperatorsManager != address(0)) revert AlreadyInitialized();
        if (_avsOperatorsManager == address(0)) revert InvalidAddress();
        avsOperatorsManager = _avsOperatorsManager;
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

    //--------------------------------------------------------------------------------------
    //------------------------------  AVS Operations  --------------------------------------
    //--------------------------------------------------------------------------------------

    // forwards a whitelisted call from the manager contract to an arbitrary target
    function forwardCall(address to, bytes calldata data) external managerOnly returns (bytes memory) {
        return Address.functionCall(to, data);
    }

    //--------------------------------------------------------------------------------------
    //--------------------------------  AVS Metadata  --------------------------------------
    //--------------------------------------------------------------------------------------

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

    function updateAvsNodeRunner(address _avsNodeRunner) external managerOnly {
        avsNodeRunner = _avsNodeRunner;
    }

    function updateEcdsaSigner(address _ecdsaSigner) external managerOnly {
        ecdsaSigner = _ecdsaSigner;
    }

    // DEPRECATED
    function getAvsInfo(address _avsRegistryCoordinator) external view returns (AvsInfo memory) {
        return avsInfos[_avsRegistryCoordinator];
    }

    //--------------------------------------------------------------------------------------
    //---------------------------------  Signatures-  --------------------------------------
    //--------------------------------------------------------------------------------------

    function isValidSignature(bytes32 _digestHash, bytes memory _signature)
        public
        view
        override
        returns (bytes4 magicValue)
    {
        (address recovered,,) = ECDSA.tryRecover(_digestHash, _signature);
        return recovered == ecdsaSigner ? this.isValidSignature.selector : bytes4(0xffffffff);
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

    modifier managerOnly() {
        if (msg.sender != avsOperatorsManager) revert NotManager();
        _;
    }
}
