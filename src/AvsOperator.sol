// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IDelegationManager} from "@eigenlayer/contracts/interfaces/IDelegationManager.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {IBeacon} from "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/// @notice This contract was forked from the EtherFi Protocol.
/// @dev Original: https://github.com/etherfi-protocol/smart-contracts/blob/syko/feature/etherfi_avs_operator/src/EtherFiAvsOperator.sol
contract AvsOperator is IERC1271, IBeacon {
    address public avsOperatorsManager;
    address public ecdsaSigner;

    error AlreadyInitialized();
    error InvalidAddress();
    error NotManager();

    /**
     * @dev Initializes the contract with the address of the AVS Operators Manager.
     * @param _avsOperatorsManager The address of the AVS Operators Manager.
     */
    function initialize(address _avsOperatorsManager) external {
        if (avsOperatorsManager != address(0)) revert AlreadyInitialized();
        if (_avsOperatorsManager == address(0)) revert InvalidAddress();
        avsOperatorsManager = _avsOperatorsManager;
    }

    /**
     * @notice Registers this contract as an operator in the Delegation Manager.
     * @dev Callable only by the manager.
     * @param _delegationManager The Delegation Manager contract address.
     * @param _detail Operator details.
     * @param _metaDataURI URI for operator metadata.
     */
    function registerAsOperator(
        IDelegationManager _delegationManager,
        IDelegationManager.OperatorDetails calldata _detail,
        string calldata _metaDataURI
    ) external managerOnly {
        _delegationManager.registerAsOperator(_detail, _metaDataURI);
    }

    /**
     * @notice Modifies the operator details of this contract in the Delegation Manager.
     * @dev Callable only by the manager.
     * @param _delegationManager The Delegation Manager contract address.
     * @param _newOperatorDetails New operator details.
     */
    function modifyOperatorDetails(
        IDelegationManager _delegationManager,
        IDelegationManager.OperatorDetails calldata _newOperatorDetails
    ) external managerOnly {
        _delegationManager.modifyOperatorDetails(_newOperatorDetails);
    }

    /**
     * @notice Updates the metadata URI of this contract as an operator in the Delegation Manager.
     * @dev Callable only by the manager.
     * @param _delegationManager The Delegation Manager contract address.
     * @param _metadataURI New metadata URI.
     */
    function updateOperatorMetadataURI(IDelegationManager _delegationManager, string calldata _metadataURI)
        external
        managerOnly
    {
        _delegationManager.updateOperatorMetadataURI(_metadataURI);
    }

    /**
     * @dev Updates the ECDSA signer address. Can only be called by the manager.
     * @param _ecdsaSigner The new address of the ECDSA signer.
     */
    function updateEcdsaSigner(address _ecdsaSigner) external managerOnly {
        if (_ecdsaSigner == address(0)) revert InvalidAddress();
        ecdsaSigner = _ecdsaSigner;
    }

    /**
     * @dev Checks if the provided signature is valid for the provided data.
     * @param _digestHash Hash of the data to be signed
     * @param _signature Signature byte array associated with _data
     * @return magicValue Returns the magic value if the signature is valid.
     */
    function isValidSignature(bytes32 _digestHash, bytes memory _signature)
        public
        view
        override
        returns (bytes4 magicValue)
    {
        (address recovered,,) = ECDSA.tryRecover(_digestHash, _signature);
        return recovered == ecdsaSigner ? this.isValidSignature.selector : bytes4(0xffffffff);
    }

    /**
     * @dev Returns the implementation address for the beacon proxy.
     * @return The address of the implementation contract.
     */
    function implementation() external view returns (address) {
        bytes32 slot = bytes32(uint256(keccak256("eip1967.proxy.beacon")) - 1);
        address implementationVariable;
        assembly {
            implementationVariable := sload(slot)
        }

        IBeacon beacon = IBeacon(implementationVariable);
        return beacon.implementation();
    }

    /**
     * @dev Modifier to make a function callable only by the manager.
     */
    modifier managerOnly() {
        if (msg.sender != avsOperatorsManager) revert NotManager();
        _;
    }
}
