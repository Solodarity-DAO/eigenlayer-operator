// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {console, Script} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

import "../src/AvsOperator.sol";
import "../src/AvsOperatorsManager.sol";

contract DeployScript is Script {
    function run() external {
        vm.startBroadcast();

        AvsOperator avsOperator = new AvsOperator();
        address proxy = Upgrades.deployUUPSProxy(
            "AvsOperatorsManager.sol", abi.encodeCall(AvsOperatorsManager.initialize, (address(avsOperator)))
        );
        console.log("uups proxy -> %s", proxy);

        AvsOperatorsManager operatorsManager = AvsOperatorsManager(proxy);
        uint256 operatorId = operatorsManager.createAvsOperator();

        address ecdsaSignerAddress = vm.envAddress("ECDSA_SIGNER_ADDRESS");
        operatorsManager.updateEcdsaSigner(operatorId, ecdsaSignerAddress);

        vm.stopBroadcast();
    }
}
