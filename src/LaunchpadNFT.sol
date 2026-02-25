// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC721} from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";

contract LaunchpadNFT is ERC721, Ownable(msg.sender) {
    uint256 public totalSupply;
    uint256 public maxSupply;
    uint256 public mintPrice;
    bool public isActive;
    bytes32 public merkleRoot;
    mapping(address => uint256) public mintedPerWallet;
    uint256 public maxPerWallet;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply,
        uint256 _mintPrice,
        uint256 _maxPerWallet
    ) ERC721(_name, _symbol) {
        maxSupply = _maxSupply;
        mintPrice = _mintPrice;
        isActive = false;
        maxPerWallet = _maxPerWallet;
    }

    function setActive(bool _isActive) external onlyOwner {
        isActive = _isActive;
    }

    function setMerkleRoot(bytes32 _root) external onlyOwner {
        merkleRoot = _root;
    }

    function mint(uint256 quantity, bytes32[] memory proof) public payable {
        require(isActive, "Contract is not active");
        require(quantity > 0, "Quantity must be greater than 0");
        require(totalSupply + quantity <= maxSupply, "Max supply reached");
        require(msg.value == mintPrice * quantity, "Incorrect payment");
        require(mintedPerWallet[msg.sender] + quantity <= maxPerWallet, "Exceeds wallet limit");
        if (merkleRoot != 0) {
            bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
            require(MerkleProof.verify(proof, merkleRoot, leaf), "Not in whitelist");
        }
        for (uint256 i = 0; i < quantity; i++) {
            totalSupply++;
            _safeMint(msg.sender, totalSupply + 1);
        }
        mintedPerWallet[msg.sender] += quantity;
    }

    function mint(uint256 quantity) external payable {
        bytes32[] memory _proof;
        mint(quantity, _proof);
    }

    function withdraw() external onlyOwner {
        (bool success,) = payable(owner()).call{value: address(this).balance}("");
        require(success, "Transfer failed");
    }
}
