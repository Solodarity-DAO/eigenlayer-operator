// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

import {AvsOperator} from "../src/AvsOperator.sol";
import {AvsOperatorsManager} from "../src/AvsOperatorsManager.sol";

contract DeployScript is Script {
    function run() external {
        vm.startBroadcast();

        AvsOperator avsOperator = new AvsOperator();
        address delegationManagerAddress = vm.envAddress("DELEGATION_MANAGER_ADDRESS");
        address proxy = Upgrades.deployUUPSProxy(
            "AvsOperatorsManager.sol",
            abi.encodeCall(AvsOperatorsManager.initialize, (delegationManagerAddress, address(avsOperator)))
        );
        console.log("AvsOperatorsManager Proxy: %s", proxy);

        AvsOperatorsManager operatorsManager = AvsOperatorsManager(proxy);
        uint256 operatorId = operatorsManager.createAvsOperator();
        console.log("AvsOperator Proxy: %s", address(operatorsManager.avsOperators(operatorId)));

        address ecdsaSignerAddress = vm.envAddress("ECDSA_SIGNER_ADDRESS");
        operatorsManager.updateEcdsaSigner(operatorId, ecdsaSignerAddress);

        vm.stopBroadcast();
    }
}
