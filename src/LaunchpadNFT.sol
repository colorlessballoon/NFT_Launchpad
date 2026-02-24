// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC721} from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

contract LaunchpadNFT is ERC721, Ownable(msg.sender) {
    uint256 public totalSupply;
    uint256 public maxSupply;
    uint256 public mintPrice;

    constructor(string memory _name, string memory _symbol, uint256 _maxSupply, uint256 _mintPrice)
        ERC721(_name, _symbol)
    {
        maxSupply = _maxSupply;
        mintPrice = _mintPrice;
    }

    function mint(uint256 quantity) external payable {
        require(quantity > 0, "Quantity must be greater than 0");
        require(totalSupply + quantity <= maxSupply, "Max supply reached");
        require(msg.value == mintPrice * quantity, "Incorrect payment");
        for (uint256 i = 0; i < quantity; i++) {
            _safeMint(msg.sender, totalSupply + 1);
            totalSupply++;
        }
    }

    function withdraw() external onlyOwner {
        (bool success,) = payable(owner()).call{value: address(this).balance}("");
        require(success, "Transfer failed");
    }
}
