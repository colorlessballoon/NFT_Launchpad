// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {LaunchpadNFT} from "../src/LaunchpadNFT.sol";
import "forge-std/console.sol";

contract LaunchpadNFTTest is Test {
    LaunchpadNFT public launchpadNFT;

    address user = address(0x1);

    function setUp() public {
        launchpadNFT = new LaunchpadNFT("LaunchpadNFT", "LPNFT", 100, 0.01 ether);
    }

    function testMintSuccess() public {
        vm.deal(user, 1 ether);

        vm.prank(user);
        launchpadNFT.mint{value: 0.01 ether}(1);

        assertEq(launchpadNFT.totalSupply(), 1);
    }
}