// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";

import {Options} from "openzeppelin-foundry-upgrades/Options.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

import {AvsOperatorsManager} from "../src/AvsOperatorsManager.sol";

contract UpdateSocketScript is Script {
    function run() external {
        vm.startBroadcast();

        address avsOperatorsManagerAddress = vm.envAddress("AVS_OPERATORS_MANAGER_ADDRESS");
        AvsOperatorsManager avsOperatorsManager = AvsOperatorsManager(avsOperatorsManagerAddress);

        address avsRegistryCoordinatorAddress = vm.envAddress("EIGENDA_REGISTRY_COORDINATOR_ADDRESS");
        uint256 operatorId = vm.promptUint("Enter operator ID");
        string memory socket = vm.prompt("Enter operator socket"); // E.g. 15.204.220.145:32005;32004

        avsOperatorsManager.updateSocket(operatorId, avsRegistryCoordinatorAddress, socket);

        vm.stopBroadcast();
    }
}
