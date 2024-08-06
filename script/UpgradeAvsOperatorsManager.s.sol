// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";

import {Options} from "openzeppelin-foundry-upgrades/Options.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

import {AvsOperatorsManager} from "../src/AvsOperatorsManager.sol";

contract UpgradeAvsOperatorsManagerScript is Script {
    function run() external {
        vm.startBroadcast();

        address avsOperatorsManagerAddress = vm.envAddress("AVS_OPERATORS_MANAGER_ADDRESS");
        address avsDirectoryAddress = vm.envAddress("EIGENLAYER_AVS_DIRECTORY_ADDRESS");

        // To upgrade we need the current contract available, and renamed, for safety checks.
        Options memory opts;
        opts.referenceContract = "AvsOperatorsManagerV1.sol";

        // Upgrades.validateUpgrade("AvsOperatorsManager.sol", opts);
        Upgrades.upgradeProxy(
            avsOperatorsManagerAddress,
            "AvsOperatorsManager.sol",
            abi.encodeCall(AvsOperatorsManager.initializeAvsDirectory, (avsDirectoryAddress)),
            opts
        );

        vm.stopBroadcast();
    }
}
