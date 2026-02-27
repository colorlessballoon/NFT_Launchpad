// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/token/common/ERC2981.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";
import "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "openzeppelin-contracts/contracts/utils/Pausable.sol";
import "erc721a/ERC721A.sol";
import {
    ContractNotActive,
    QuantityZero,
    MaxSupplyReached,
    IncorrectPayment,
    ExceedsWalletLimit,
    SaleNotActive,
    NotInWhitelist,
    TransferFailed
} from "./errors/LaunchpadErrors.sol";

contract LaunchpadNFT is ERC721A, Ownable(msg.sender), ERC2981, ReentrancyGuard, Pausable {
    using Strings for uint256;
    //合约最大铸造数量

    uint256 public maxSupply;
    //铸造所需金额
    uint256 public mintPrice;
    //销售开关
    bool public isActive;
    //merkle树root
    bytes32 public merkleRoot;
    //记录每个地址的铸造数量
    mapping(address => uint256) public mintedPerWallet;
    uint256 public maxPerWallet;
    //白名单销售开关
    bool public whitelistSaleActive;
    //公开销售开关
    bool public publicSaleActive;

    string private baseTokenURI;
    string public hiddenURI;
    bool public revealed;

    uint256 public platformFee;
    address public feeReceiver;

    event ActiveUpdated(bool isActive);
    event WhitelistSaleActiveUpdated(bool active);
    event PublicSaleActiveUpdated(bool active);
    event MerkleRootUpdated(bytes32 merkleRoot);
    event BaseURIUpdated(string baseURI);
    event Revealed();
    event Withdrawn(uint256 balance, uint256 feeAmount, uint256 creatorAmount);

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply,
        uint256 _mintPrice,
        uint256 _maxPerWallet,
        string memory _hiddenURI,
        address royaltyReceiver,
        uint96 royaltyFee,
        uint256 _platformFee,
        address _feeReceiver
    ) ERC721A(_name, _symbol) {
        maxSupply = _maxSupply;
        mintPrice = _mintPrice;
        isActive = false;
        maxPerWallet = _maxPerWallet;
        hiddenURI = _hiddenURI;
        _setDefaultRoyalty(royaltyReceiver, royaltyFee);
        platformFee = _platformFee;
        feeReceiver = _feeReceiver;
    }

    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    function setActive(bool _isActive) external onlyOwner {
        isActive = _isActive;
        emit ActiveUpdated(_isActive);
    }

    function setWhitelistSaleActive(bool _active) external onlyOwner {
        whitelistSaleActive = _active;
        emit WhitelistSaleActiveUpdated(_active);
    }

    function setPublicSaleActive(bool _active) external onlyOwner {
        publicSaleActive = _active;
        emit PublicSaleActiveUpdated(_active);
    }

    function setMerkleRoot(bytes32 _root) external onlyOwner {
        merkleRoot = _root;
        emit MerkleRootUpdated(_root);
    }

    function setBaseURI(string memory _baseURI) external onlyOwner {
        baseTokenURI = _baseURI;
        emit BaseURIUpdated(_baseURI);
    }

    function reveal() external onlyOwner {
        revealed = true;
        emit Revealed();
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function mint(uint256 quantity, bytes32[] memory _proof) external payable nonReentrant whenNotPaused {
        _mintLogic(quantity, _proof);
    }

    function mint(uint256 quantity) external payable nonReentrant whenNotPaused {
        bytes32[] memory _proof;
        _mintLogic(quantity, _proof);
    }

    function _mintLogic(uint256 quantity, bytes32[] memory proof) internal {
        if (!isActive) revert ContractNotActive();
        if (quantity == 0) revert QuantityZero();
        if (totalSupply() + quantity > maxSupply) revert MaxSupplyReached();
        if (msg.value != mintPrice * quantity) revert IncorrectPayment();
        if (mintedPerWallet[msg.sender] + quantity > maxPerWallet) revert ExceedsWalletLimit();
        if (!whitelistSaleActive && !publicSaleActive) revert SaleNotActive();
        if (whitelistSaleActive) {
            if (merkleRoot != 0) {
                bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
                if (!MerkleProof.verify(proof, merkleRoot, leaf)) revert NotInWhitelist();
            }
        }
        _safeMint(msg.sender, quantity);
        mintedPerWallet[msg.sender] += quantity;
    }

    function withdraw() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        uint256 feeAmount = (balance * platformFee) / 10000;
        uint256 creatorAmount = balance - feeAmount;

        (bool successFee,) = payable(feeReceiver).call{value: feeAmount}("");
        (bool successCreator,) = payable(owner()).call{value: creatorAmount}("");
        if (!successFee || !successCreator) revert TransferFailed();
        emit Withdrawn(balance, feeAmount, creatorAmount);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "Nonexistent token");
        if (!revealed) {
            return hiddenURI;
        }
        return string(abi.encodePacked(baseTokenURI, tokenId.toString(), ".json"));
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721A, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
