// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";

import {AvsOperatorsManager} from "../src/AvsOperatorsManager.sol";
import {Options} from "openzeppelin-foundry-upgrades/Options.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract UpgradeAvsOperatorsManagerScript is Script {
    function run() external {
        vm.startBroadcast();

        address avsOperatorsManagerAddress = vm.envAddress("AVS_OPERATORS_MANAGER_ADDRESS");

        // To upgrade we need the previous contract available, and contract renamed to match filename, for safety checks.
        Options memory opts;
        opts.referenceContract = "AvsOperatorsManagerOld.sol";

        // Upgrades.validateUpgrade("AvsOperatorsManager.sol", opts);
        Upgrades.upgradeProxy(avsOperatorsManagerAddress, "AvsOperatorsManager.sol", "", opts);

        vm.stopBroadcast();
    }
}
