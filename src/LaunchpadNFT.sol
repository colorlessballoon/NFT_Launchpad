// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC721} from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";
import "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

contract LaunchpadNFT is ERC721, Ownable(msg.sender), ReentrancyGuard {
    using Strings for uint256;
    //合约总铸造数量

    uint256 public totalSupply;
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

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply,
        uint256 _mintPrice,
        uint256 _maxPerWallet,
        string memory _hiddenURI
    ) ERC721(_name, _symbol) {
        maxSupply = _maxSupply;
        mintPrice = _mintPrice;
        isActive = false;
        maxPerWallet = _maxPerWallet;
        hiddenURI = _hiddenURI;
    }

    function setActive(bool _isActive) external onlyOwner {
        isActive = _isActive;
    }

    function setWhitelistSaleActive(bool _active) external onlyOwner {
        whitelistSaleActive = _active;
    }

    function setPublicSaleActive(bool _active) external onlyOwner {
        publicSaleActive = _active;
    }

    function setMerkleRoot(bytes32 _root) external onlyOwner {
        merkleRoot = _root;
    }

    function setBaseURI(string memory _baseURI) external onlyOwner {
        baseTokenURI = _baseURI;
    }

    function reveal() external onlyOwner {
        revealed = true;
    }

    function mint(uint256 quantity, bytes32[] memory _proof) external payable nonReentrant {
        _mintLogic(quantity, _proof);
    }

    function mint(uint256 quantity) external payable nonReentrant {
        bytes32[] memory _proof;
        _mintLogic(quantity, _proof);
    }

    function _mintLogic(uint256 quantity, bytes32[] memory proof) internal {
        require(isActive, "Contract is not active");
        require(quantity > 0, "Quantity must be greater than 0");
        require(totalSupply + quantity <= maxSupply, "Max supply reached");
        require(msg.value == mintPrice * quantity, "Incorrect payment");
        require(mintedPerWallet[msg.sender] + quantity <= maxPerWallet, "Exceeds wallet limit");
        require(whitelistSaleActive || publicSaleActive, "Sale not active");
        if (whitelistSaleActive) {
            if (merkleRoot != 0) {
                bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
                require(MerkleProof.verify(proof, merkleRoot, leaf), "Not in whitelist");
            }
        }
        for (uint256 i = 0; i < quantity; i++) {
            _safeMint(msg.sender, totalSupply + 1);
            totalSupply++;
        }
        mintedPerWallet[msg.sender] += quantity;
    }

    function withdraw() external onlyOwner nonReentrant {
        (bool success,) = payable(owner()).call{value: address(this).balance}("");
        require(success, "Transfer failed");
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Nonexistent token");
        if (!revealed) {
            return hiddenURI;
        }
        return string(abi.encodePacked(baseTokenURI, tokenId.toString(), ".json"));
    }
}
