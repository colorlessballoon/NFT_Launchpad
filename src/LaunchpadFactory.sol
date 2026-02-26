// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./LaunchpadNFT.sol";

contract LaunchpadFactory is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    address[] public allNFTs;
    uint96 public platformFee;
    address public feeReceiver;

    event NFTCreated(address indexed nftAddress);

    function initialize(uint96 _platformFee, address _receiver) public initializer {
        __Ownable_init(msg.sender);
        platformFee = _platformFee;
        feeReceiver = _receiver;
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
        LaunchpadNFT nft = new LaunchpadNFT{salt: salt}(
            name_,
            symbol_,
            maxSupply_,
            mintPrice_,
            maxPerWallet_,
            hiddenURI_,
            royaltyReceiver_,
            royaltyFee_,
            platformFee,
            feeReceiver
        );

        // 将 NFT 的拥有者从工厂合约转移给当前调用者（例如测试合约或前端调用者）
        nft.transferOwnership(msg.sender);

        allNFTs.push(address(nft));

        emit NFTCreated(address(nft));

        return address(nft);
    }

    function getAllNFTs() external view returns (address[] memory) {
        return allNFTs;
    }

    /// @notice UUPS 升级入口，保持简单的 `upgradeTo(address)` 接口，方便代理调用
    function upgradeTo(address newImplementation) external onlyOwner {
        // OZ v5 只提供 upgradeToAndCall，这里用空 calldata 适配
        upgradeToAndCall(newImplementation, bytes(""));
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
