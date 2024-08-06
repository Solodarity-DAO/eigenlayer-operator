// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";

import {AvsOperatorsManager} from "../src/AvsOperatorsManager.sol";

contract UpdateAvsWhitelistScript is Script {
    function run() external {
        vm.startBroadcast();

        address avsOperatorsManagerAddress = vm.envAddress("AVS_OPERATORS_MANAGER_ADDRESS");
        AvsOperatorsManager avsOperatorsManager = AvsOperatorsManager(avsOperatorsManagerAddress);

        address avsRegistryCoordinatorAddress = vm.envAddress("EIGENDA_REGISTRY_COORDINATOR_ADDRESS");
        uint256 operatorId = vm.promptUint("Enter operator ID: ");
        avsOperatorsManager.updateAvsWhitelist(operatorId, avsRegistryCoordinatorAddress, true);

        vm.stopBroadcast();
    }
}
