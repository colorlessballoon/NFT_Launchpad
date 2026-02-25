// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {LaunchpadNFT} from "../src/LaunchpadNFT.sol";
import "forge-std/console.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";

contract LaunchpadNFTTest is Test {
    LaunchpadNFT public launchpadNFT;
    bytes32[] whitelistProof;
    bytes32 leaf;
    bytes32 merkleRoot;

    address user = address(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4);

    function setUp() public {
        launchpadNFT = new LaunchpadNFT("LaunchpadNFT", "LPNFT", 100, 0.01 ether, 2);
        launchpadNFT.setActive(true);
        leaf = keccak256(abi.encodePacked(user));
        merkleRoot = 0x9d997719c0a5b5f6db9b8ac69a988be57cf324cb9fffd51dc2c37544bb520d65;
        //launchpadNFT.setMerkleRoot(0x1747720d9e8d62451fa5a88ef321b2b5af7a1e3f8097af15786de53ab02341b0);
        whitelistProof.push(0x999bf57501565dbd2fdcea36efa2b9aef8340a8901e3459f4a4c926275d36cdb);
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
        LaunchpadNFT nft = new LaunchpadNFT("TestNFT", "TNFT", 100, 0.01 ether, 200);
        nft.setActive(true);
        vm.deal(user, 100 ether);
        vm.prank(user);
        nft.mint{value: 1 ether}(100);
        vm.prank(user);
        vm.expectRevert("Max supply reached");
        nft.mint{value: 0.01 ether}(1);
        assertEq(nft.totalSupply(), 100);
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

    function testMintRevertIfMintInactive() public {
        vm.deal(user, 1 ether);
        launchpadNFT.setActive(false);
        vm.prank(user);
        vm.expectRevert("Contract is not active");
        launchpadNFT.mint{value: 0.01 ether}(1);
        vm.stopPrank();
        assertEq(launchpadNFT.totalSupply(), 0);
    }

    function testMintAfterActivating() public {
        vm.deal(user, 1 ether);
        vm.prank(user);
        launchpadNFT.mint{value: 0.01 ether}(1);
        vm.stopPrank();
        assertEq(launchpadNFT.totalSupply(), 1);
    }

    function testMintNoInWhitelist() public {
        launchpadNFT.setMerkleRoot(merkleRoot);
        vm.deal(address(2), 1 ether);
        vm.prank(address(2));
        vm.expectRevert("Not in whitelist");
        launchpadNFT.mint{value: 0.01 ether}(1, whitelistProof);
        assertEq(launchpadNFT.totalSupply(), 0);
    }

    function testMintInWhitelist() public {
        launchpadNFT.setMerkleRoot(merkleRoot);
        vm.deal(user, 1 ether);
        vm.prank(user);
        launchpadNFT.mint{value: 0.01 ether}(1, whitelistProof);
        assertEq(launchpadNFT.totalSupply(), 1);
    }

    function testMintWithinLimit() public {
        launchpadNFT.setMerkleRoot(merkleRoot);
        vm.deal(user, 1 ether);
        vm.prank(user);
        launchpadNFT.mint{value: 0.02 ether}(2, whitelistProof);
        assertEq(launchpadNFT.totalSupply(), 2);
        assertEq(launchpadNFT.mintedPerWallet(user), 2);
    }

    function testMintExceedsWalletLimit() public {
        launchpadNFT.setMerkleRoot(merkleRoot);
        vm.deal(user, 1 ether);
        vm.startPrank(user);
        launchpadNFT.mint{value: 0.02 ether}(2, whitelistProof);
        vm.expectRevert("Exceeds wallet limit");
        launchpadNFT.mint{value: 0.01 ether}(1, whitelistProof);
        vm.stopPrank();
        assertEq(launchpadNFT.totalSupply(), 2);
        assertEq(launchpadNFT.mintedPerWallet(user), 2);
    }

    receive() external payable {}
}
