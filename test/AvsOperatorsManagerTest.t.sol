// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {console, Test} from "forge-std/Test.sol";
import {VmSafe} from "forge-std/Vm.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

import "../src/AvsOperator.sol";
import "../src/AvsOperatorsManager.sol";

contract AvsOperatorsManagerTest is Test {
    AvsOperatorsManager operatorsManager;

    function setUp() public {
        AvsOperator avsOperator = new AvsOperator();

        address proxy = Upgrades.deployUUPSProxy(
            "AvsOperatorsManager.sol", abi.encodeCall(AvsOperatorsManager.initialize, (address(avsOperator)))
        );

        console.log("uups proxy -> %s", proxy);
        operatorsManager = AvsOperatorsManager(proxy);

        address implAddressV1 = Upgrades.getImplementationAddress(proxy);
        console.log("impl proxy -> %s", implAddressV1);
    }

    function test_initialize_SetsOwner() public view {
        assertEq(operatorsManager.owner(), address(this));
    }

    function test_createAvsOperator_SetsManager() public {
        uint256 operatorId = operatorsManager.createAvsOperator();
        assertEq(operatorsManager.avsOperators(operatorId).avsOperatorsManager(), address(operatorsManager));
    }

    function test_updateEcdsaSigner_SetsSigner() public {
        VmSafe.Wallet memory ecdsaSigner = vm.createWallet("ecdsaSigner");
        uint256 operatorId = operatorsManager.createAvsOperator();
        operatorsManager.updateEcdsaSigner(operatorId, ecdsaSigner.addr);
        assertEq(operatorsManager.avsOperators(operatorId).ecdsaSigner(), ecdsaSigner.addr);
    }

    function test_updateEcdsaSigner_RevertWhen_NotManager() public {
        uint256 operatorId = operatorsManager.createAvsOperator();
        vm.expectRevert(AvsOperatorsManager.NotAdmin.selector);
        address notAdminAddress = vm.createWallet("NotAdmin").addr;
        vm.prank(notAdminAddress);
        operatorsManager.updateEcdsaSigner(operatorId, notAdminAddress);
    }

    function test_updateAdmin_SetsAdmin() public {
        address adminAddress = vm.createWallet("Admin").addr;
        operatorsManager.updateAdmin(adminAddress, true);
        assert(operatorsManager.admins(adminAddress));
    }

    function test_updateAdmin_RevertWhen_NotOwner() public {
        address notOwnerAddress = vm.createWallet("NotOwner").addr;
        bytes memory expectedError =
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, notOwnerAddress);
        vm.expectRevert(expectedError);
        vm.prank(notOwnerAddress);
        operatorsManager.updateAdmin(notOwnerAddress, true);
    }
}
