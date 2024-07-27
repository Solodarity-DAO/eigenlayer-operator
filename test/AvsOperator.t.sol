// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {VmSafe} from "forge-std/Vm.sol";

import {AvsOperator} from "../src/AvsOperator.sol";

contract AvsOperatorTest is Test {
    AvsOperator avsOperator;
    VmSafe.Wallet avsOperatorsManager;
    VmSafe.Wallet ecdsaSigner;
    bytes32 digestHash = keccak256("Hello, World!");

    function setUp() public {
        avsOperatorsManager = vm.createWallet("avsOperatorsManager");
        ecdsaSigner = vm.createWallet("ecdsaSigner");

        avsOperator = new AvsOperator();
        avsOperator.initialize(avsOperatorsManager.addr);

        vm.prank(avsOperatorsManager.addr);
        avsOperator.updateEcdsaSigner(ecdsaSigner.addr);
    }

    function test_isValidSignature_Valid() public {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ecdsaSigner, digestHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        bytes4 magicValue = avsOperator.isValidSignature(digestHash, signature);
        assertEq(magicValue, avsOperator.isValidSignature.selector);
    }

    function test_isValidSignature_Invalid() public {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ecdsaSigner, digestHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        signature[0] = 0;
        bytes4 magicValue = avsOperator.isValidSignature(digestHash, signature);
        assertEq(magicValue, bytes4(0xffffffff));
    }
}
