// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";

import {IDelegationManager} from "../src/eigenlayer-interfaces/IDelegationManager.sol";

import {AvsOperatorsManager} from "../src/AvsOperatorsManager.sol";

contract RegisterOperatorScript is Script {
    function run() external {
        vm.startBroadcast();

        address avsOperatorsManagerAddress = vm.envAddress("AVS_OPERATORS_MANAGER_ADDRESS");
        AvsOperatorsManager operatorsManager = AvsOperatorsManager(avsOperatorsManagerAddress);

        uint256 operatorId = vm.promptUint("Enter operator ID: ");
        address earningsReceiver = vm.promptAddress("Enter earnings receiver address: ");
        IDelegationManager.OperatorDetails memory operatorDetails = IDelegationManager.OperatorDetails({
            __deprecated_earningsReceiver: earningsReceiver,
            delegationApprover: address(0),
            stakerOptOutWindowBlocks: 0
        });
        string memory metaDataURI =
            "https://raw.githubusercontent.com/klassicd/eigenlayer-operator/main/operator/metadata.json";

        operatorsManager.registerAsOperator(operatorId, operatorDetails, metaDataURI);

        vm.stopBroadcast();
    }
}
