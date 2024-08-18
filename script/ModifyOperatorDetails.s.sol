// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";

import {AvsOperatorsManager} from "../src/AvsOperatorsManager.sol";
import {IDelegationManager} from "../src/eigenlayer-interfaces/IDelegationManager.sol";

contract ModifyOperatorDetailsScript is Script {
    function run() external {
        vm.startBroadcast();

        address avsOperatorsManagerAddress = vm.envAddress("AVS_OPERATORS_MANAGER_ADDRESS");
        AvsOperatorsManager avsOperatorsManager = AvsOperatorsManager(avsOperatorsManagerAddress);

        uint256 operatorId = vm.promptUint("Enter operator ID");
        address earningsReceiver = vm.promptAddress("Enter earnings receiver address: ");

        IDelegationManager.OperatorDetails memory operatorDetails = IDelegationManager.OperatorDetails({
            __deprecated_earningsReceiver: earningsReceiver,
            delegationApprover: address(0),
            stakerOptOutWindowBlocks: 0
        });

        avsOperatorsManager.modifyOperatorDetails(operatorId, operatorDetails);

        vm.stopBroadcast();
    }
}
