// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {LaunchpadFactory} from "../src/LaunchpadFactory.sol";
import {LaunchpadFactoryV2} from "../src/LaunchpadFactoryV2.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {LaunchpadNFT} from "../src/LaunchpadNFT.sol";

contract LaunchpadFactorTest is Test {
    LaunchpadFactory factory;
    address user = address(0xf12);
    uint96 constant PLATFORM_FEE = 500; // 5%
    address public platform = address(0x9999);

    function setUp() public {
        LaunchpadFactory implementation = new LaunchpadFactory();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation), abi.encodeCall(LaunchpadFactory.initialize, (PLATFORM_FEE, platform))
        );

        factory = LaunchpadFactory(address(proxy));
    }

    function _computeCreate2Address(
        bytes32 salt,
        bytes memory constructorArgs
    ) internal view returns (address) {
        bytes memory bytecode = abi.encodePacked(type(LaunchpadNFT).creationCode, constructorArgs);
        bytes32 hash =
            keccak256(abi.encodePacked(bytes1(0xff), address(factory), salt, keccak256(bytecode)));
        return address(uint160(uint256(hash)));
    }

    function testCreate2AddressPrediction() public {
        bytes32 salt = keccak256("TEST_SALT");

        bytes memory args = abi.encode(
            "Test NFT", "TEST", 100, 0.01 ether, 2, "hidden.json", address(this), 500, PLATFORM_FEE, platform
        );

        address predicted = _computeCreate2Address(salt, args);

        address deployed = factory.createLaunchpadNFT(
            salt, "Test NFT", "TEST", 100, 0.01 ether, 2, "hidden.json", address(this), 500
        );
        assertEq(predicted, deployed);
    }

    function testCreate2RevertIfSaltReused() public {
        bytes32 salt = keccak256("TEST_SALT");

        factory.createLaunchpadNFT(
            salt, "Test", "TEST", 100, 0.01 ether, 2, "hidden.json", address(this), 500
        );
        vm.expectRevert();
        factory.createLaunchpadNFT(
            salt, "Test", "TEST", 100, 0.01 ether, 2, "hidden.json", address(this), 500
        );
    }

    function testDifferentSaltDifferentAddress() public {
        bytes32 salt1 = keccak256("SALT1");
        bytes32 salt2 = keccak256("SALT2");

        address nft1 =
            factory.createLaunchpadNFT(salt1, "Test1", "T1", 100, 0.01 ether, 2, "hidden.json", address(this), 500);

        address nft2 =
            factory.createLaunchpadNFT(salt2, "Test2", "T2", 100, 0.01 ether, 2, "hidden.json", address(this), 500);

        assertTrue(nft1 != nft2);
    }

    function testDeployedNFTWorks() public {
        bytes32 salt = keccak256("WORK_SALT");

        address nftAddress =
            factory.createLaunchpadNFT(salt, "Test NFT", "TEST", 100, 0.01 ether, 2, "hidden.json", address(this), 500);

        LaunchpadNFT nft = LaunchpadNFT(nftAddress);

        // 由工厂拥有者（测试合约）配置销售参数
        vm.prank(address(this));
        nft.setActive(true);
        nft.setPublicSaleActive(true);

        // 由外部用户地址实际进行 mint，避免向非 ERC721Receiver 合约地址安全转账导致回退
        vm.deal(user, 1 ether);
        vm.prank(user);
        nft.mint{value: 0.01 ether}(1);
        assertEq(nft.totalSupply(), 1);
    }

    function testFactoryUpgrade() public {
        bytes32 salt = keccak256("SALT");
        factory.createLaunchpadNFT(salt, "Test NFT", "TEST", 100, 0.01 ether, 2, "hidden.json", address(this), 500);
        assertEq(factory.getAllNFTs().length, 1);

        LaunchpadFactoryV2 newImpl = new LaunchpadFactoryV2();
        factory.upgradeTo(address(newImpl));
        assertEq(factory.getAllNFTs().length, 1);

        LaunchpadFactoryV2 upgraded = LaunchpadFactoryV2(address(factory));
        assertEq(upgraded.version(), "V2");
    }

    function testUpgradeOnlyOwner() public {
        LaunchpadFactoryV2 newImpl = new LaunchpadFactoryV2();

        vm.prank(user);
        vm.expectRevert();
        factory.upgradeTo(address(newImpl));
    }
}
