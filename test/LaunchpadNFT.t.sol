// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {LaunchpadNFT} from "../src/LaunchpadNFT.sol";
import "openzeppelin-contracts/contracts/utils/Pausable.sol";
import {
    ContractNotActive,
    QuantityZero,
    MaxSupplyReached,
    IncorrectPayment,
    ExceedsWalletLimit,
    SaleNotActive,
    NotInWhitelist,
    TransferFailed
} from "../src/errors/LaunchpadErrors.sol";

contract LaunchpadNFTTest is Test {
    LaunchpadNFT public launchpadNFT;

    address user = address(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4);
    address attacker = address(0x2);
    bytes32 public merkleRoot = 0x9d997719c0a5b5f6db9b8ac69a988be57cf324cb9fffd51dc2c37544bb520d65;
    bytes32[] public proof;
    uint256 constant MAX_SUPPLY = 100;
    uint256 constant PRICE = 0.01 ether;
    uint256 constant MAX_PER_WALLET = 2;
    uint256 constant PLATFORM_FEE = 500; // 5%
    address public platform = address(0x1234);

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        launchpadNFT = new LaunchpadNFT(
            "LaunchpadNFT",
            "LPNFT",
            MAX_SUPPLY,
            PRICE,
            MAX_PER_WALLET,
            "hidden.json",
            address(this),
            500,
            PLATFORM_FEE,
            platform
        );
        launchpadNFT.setActive(true);
        proof.push(0x999bf57501565dbd2fdcea36efa2b9aef8340a8901e3459f4a4c926275d36cdb);
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC SALE TESTS
    //////////////////////////////////////////////////////////////*/

    function testPublicMintSuccess() public {
        launchpadNFT.setPublicSaleActive(true);

        vm.deal(user, 1 ether);

        vm.prank(user);
        launchpadNFT.mint{value: PRICE}(1);

        assertEq(launchpadNFT.totalSupply(), 1);
    }

    function testPublicMintRevertIfIncorrectPayment() public {
        launchpadNFT.setPublicSaleActive(true);

        vm.deal(user, 1 ether);

        vm.prank(user);
        vm.expectRevert(IncorrectPayment.selector);
        launchpadNFT.mint{value: 0.005 ether}(1);
    }

    function testPublicMintRevertIfExceedsWalletLimit() public {
        launchpadNFT.setPublicSaleActive(true);

        vm.deal(user, 1 ether);

        vm.startPrank(user);
        launchpadNFT.mint{value: PRICE * 2}(2);

        vm.expectRevert(ExceedsWalletLimit.selector);
        launchpadNFT.mint{value: PRICE}(1);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        MAX SUPPLY TEST
    //////////////////////////////////////////////////////////////*/

    function testMintRevertIfExceedsMaxSupply() public {
        LaunchpadNFT nft = new LaunchpadNFT(
            "TestNFT", "TNFT", 100, PRICE, 200, "hidden.json", address(this), 500, PLATFORM_FEE, platform
        );

        nft.setActive(true);
        nft.setPublicSaleActive(true);

        vm.deal(user, 100 ether);

        vm.startPrank(user);
        nft.mint{value: PRICE * 100}(100);

        vm.expectRevert(MaxSupplyReached.selector);
        nft.mint{value: PRICE}(1);
        vm.stopPrank();

        assertEq(nft.totalSupply(), 100);
    }

    /*//////////////////////////////////////////////////////////////
                        WHITELIST TESTS
    //////////////////////////////////////////////////////////////*/

    function testWhitelistMintSuccess() public {
        launchpadNFT.setWhitelistSaleActive(true);
        launchpadNFT.setMerkleRoot(merkleRoot);
        vm.deal(user, 1 ether);

        vm.prank(user);
        launchpadNFT.mint{value: PRICE}(1, proof);

        assertEq(launchpadNFT.totalSupply(), 1);
    }

    function testWhitelistRejectNonWhitelist() public {
        launchpadNFT.setWhitelistSaleActive(true);
        launchpadNFT.setMerkleRoot(merkleRoot);
        vm.deal(attacker, 1 ether);

        vm.prank(attacker);
        vm.expectRevert(NotInWhitelist.selector);
        launchpadNFT.mint{value: PRICE}(1, proof);
    }

    /*//////////////////////////////////////////////////////////////
                        SALE STATE TEST
    //////////////////////////////////////////////////////////////*/

    function testMintRevertIfSaleNotActive() public {
        vm.deal(user, 1 ether);

        vm.prank(user);
        vm.expectRevert(SaleNotActive.selector);
        launchpadNFT.mint{value: PRICE}(1);
    }

    function testMintRevertIfContractInactive() public {
        launchpadNFT.setActive(false);
        launchpadNFT.setPublicSaleActive(true);

        vm.deal(user, 1 ether);

        vm.prank(user);
        vm.expectRevert(ContractNotActive.selector);
        launchpadNFT.mint{value: PRICE}(1);
    }

    /*//////////////////////////////////////////////////////////////
                            WITHDRAW TEST
    //////////////////////////////////////////////////////////////*/

    function testWithdraw() public {
        launchpadNFT.setPublicSaleActive(true);

        vm.deal(user, 1 ether);

        vm.prank(user);
        launchpadNFT.mint{value: PRICE}(1);

        uint256 platformBalanceBefore = platform.balance;
        uint256 ownerBalanceBefore = address(this).balance;

        launchpadNFT.withdraw();

        uint256 platformBalanceAfter = platform.balance;
        uint256 ownerBalanceAfter = address(this).balance;

        uint256 platformDelta = platformBalanceAfter - platformBalanceBefore;
        uint256 ownerDelta = ownerBalanceAfter - ownerBalanceBefore;

        // 平台与创作者都应拿到一部分
        assertGt(platformDelta, 0);
        assertGt(ownerDelta, 0);
        // 两者之和等于合约收到的总金额
        assertEq(platformDelta + ownerDelta, PRICE);
    }

    /*//////////////////////////////////////////////////////////////
                            WITHDRAW TEST
    //////////////////////////////////////////////////////////////*/
    function testTokenURIHiddenBeforeReveal() public {
        launchpadNFT.setPublicSaleActive(true);
        vm.deal(user, 1 ether);
        vm.prank(user);
        launchpadNFT.mint{value: PRICE}(1);

        string memory uri = launchpadNFT.tokenURI(1);
        assertEq(uri, "hidden.json");
    }

    function testTokenURIAfterReveal() public {
        launchpadNFT.setPublicSaleActive(true);
        vm.deal(user, 1 ether);
        vm.prank(user);
        launchpadNFT.mint{value: PRICE}(1);
        launchpadNFT.setBaseURI("ipfs://base/");
        launchpadNFT.reveal();
        string memory uri = launchpadNFT.tokenURI(1);
        assertEq(uri, "ipfs://base/1.json");
    }

    function testMintRevertWhenPaused() public {
        launchpadNFT.setPublicSaleActive(true);
        launchpadNFT.pause();

        vm.deal(user, 1 ether);
        vm.prank(user);
        vm.expectRevert(Pausable.EnforcedPause.selector);
        launchpadNFT.mint{value: PRICE}(1);
    }

    function testRoyaltyInfo() public view {
        (address receiver, uint256 royaltyAmount) = launchpadNFT.royaltyInfo(1, 1 ether);
        assertEq(receiver, launchpadNFT.owner());
        assertEq(royaltyAmount, 0.05 ether);
    }

    receive() external payable {}
}
