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

    function testMintRevertIfIncorrectPayment() public {
        vm.deal(user, 1 ether);
        vm.prank(user);
        vm.expectRevert("Incorrect payment");
        launchpadNFT.mint{value: 0.005 ether}(1);
        vm.stopPrank();
        assertEq(launchpadNFT.totalSupply(), 0);
    }

    function testMintRevertIfExceedsMaxSupply() public {
        vm.deal(user, 100 ether);
        vm.prank(user);
        launchpadNFT.mint{value: 1 ether}(100);
        vm.prank(user);
        vm.expectRevert("Max supply reached");
        launchpadNFT.mint{value: 0.01 ether}(1);
        assertEq(launchpadNFT.totalSupply(), 100);
    }

    function testWithdraw() public {
        vm.deal(user, 1 ether);

        vm.prank(user);
        launchpadNFT.mint{value: 0.01 ether}(1);
        vm.stopPrank();

        uint256 ownerBalanceBefore = address(this).balance;
        launchpadNFT.withdraw();
        uint256 ownerBalanceAfter = address(this).balance;
        assertGt(ownerBalanceAfter, ownerBalanceBefore);
    }

    receive() external payable {}
}
