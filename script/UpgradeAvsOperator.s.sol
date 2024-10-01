// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";

import {AvsOperator} from "../src/AvsOperator.sol";
import {AvsOperatorsManager} from "../src/AvsOperatorsManager.sol";

contract UpgradeAvsOperatorScript is Script {
    function run() external {
        vm.startBroadcast();

        address avsOperatorsManagerAddress = vm.envAddress("AVS_OPERATORS_MANAGER_ADDRESS");
        AvsOperatorsManager avsOperatorsManager = AvsOperatorsManager(avsOperatorsManagerAddress);

        // Deploy new contract and upgrade implementation
        AvsOperator avsOperator = new AvsOperator();
        avsOperatorsManager.upgradeAvsOperator(address(avsOperator));

        vm.stopBroadcast();
    }
}
