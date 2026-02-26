// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./LaunchpadNFT.sol";

contract LaunchpadFactory is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    address[] public allNFTs;

    event NFTCreated(address indexed nftAddress);

    error AlreadyDeployed();

    function initialize() public initializer {
        __Ownable_init(msg.sender);
    }

    function createLaunchpadNFT(
        bytes32 salt,
        string memory name_,
        string memory symbol_,
        uint256 maxSupply_,
        uint256 mintPrice_,
        uint256 maxPerWallet_,
        string memory hiddenURI_,
        address royaltyReceiver_,
        uint96 royaltyFee_
    ) external onlyOwner returns (address) {
        bytes memory constructorArgs =
            abi.encode(name_, symbol_, maxSupply_, mintPrice_, maxPerWallet_, hiddenURI_, royaltyReceiver_, royaltyFee_);

        address predicted = computeAddress(salt, constructorArgs);

        if (predicted.code.length != 0) revert AlreadyDeployed();

        LaunchpadNFT nft = new LaunchpadNFT{salt: salt}(
            name_, symbol_, maxSupply_, mintPrice_, maxPerWallet_, hiddenURI_, royaltyReceiver_, royaltyFee_
        );

        // 将 NFT 的拥有者从工厂合约转移给当前调用者（例如测试合约或前端调用者）
        nft.transferOwnership(msg.sender);

        allNFTs.push(address(nft));

        emit NFTCreated(address(nft));

        return address(nft);
    }

    function computeAddress(bytes32 salt, bytes memory constructorArgs) public view returns (address) {
        bytes memory bytecode = abi.encodePacked(type(LaunchpadNFT).creationCode, constructorArgs);

        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(bytecode)));
        return address(uint160(uint256(hash)));
    }

    function getAllNFTs() external view returns (address[] memory) {
        return allNFTs;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
