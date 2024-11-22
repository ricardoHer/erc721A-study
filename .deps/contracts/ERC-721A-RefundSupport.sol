// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import "https://github.com/exo-digital-labs/ERC721R/blob/main/contracts/ERC721A.sol";
import "https://github.com/exo-digital-labs/ERC721R/blob/main/contracts/IERC721R.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Web3Builders is ERC721A, Ownable {
    // Mint information
    uint256 public constant mintPrice = 1 ether;
    uint256 public constant maxMintPerUser = 5;
    uint256 public constant maxMintSupply = 100;

    // Refund information
    uint256 public constant refundPeriod = 3 minutes;
    uint256 public refundEndTimestamp;

    address public refundAddress;
    
    mapping(uint256 => uint256) public refundEndTimestamps;
    mapping(uint256 => bool) public hasRefunded;

    constructor()
        ERC721A("Web3Builders", "WE3")
        Ownable(msg.sender)
    {
        refundAddress = address(this);
        refundEndTimestamp = block.timestamp + refundPeriod;

    }

    function _baseURI() internal pure override returns (string memory) {
        return "ipfs://QmbseRTJWSsLfhsiWwuB2R7EtN93TxfoaMz1S5FXtsFEUB/";
    }

    function safeMint(uint256 quantity) public payable  {
        require(msg.value >= mintPrice * quantity, "Not enough funds");
        require(_numberMinted(msg.sender) + quantity <= maxMintPerUser, "Mint limit");
        require(_totalMinted() + quantity <= maxMintSupply, "Sold out");

        _safeMint(msg.sender, quantity);
        refundEndTimestamp = block.timestamp + refundPeriod;

        for (uint256 i = _currentIndex - quantity; i < _currentIndex; i++) 
        {
            refundEndTimestamps[i] = refundEndTimestamp;
        }
    }

    function refund(uint256 tokenId) external {
        require(block.timestamp < getRefundDeadline(tokenId), "Refund period experiod");
        // you have to be the owner of the NFT
        require(msg.sender == ownerOf(tokenId), "Not your NFT");
        uint256 refundAmount = getRefundAmount(tokenId);

        // transfer the ownership of NFT
        _transfer(msg.sender, refundAddress, tokenId);

        // This line was moved befor to prevent the reentrance attacks,
        // Imagine trying to refund many times at once, if the tokenId was not flagged refunde
        // the attacker might be able to refund multiple times before seting this refund as true.
        // mark refunded
        hasRefunded[tokenId] = true;
        // pay atention to that, it's very important thing to think.

        // refund the price
        Address.sendValue(payable(msg.sender), refundAmount);
    }

    function getRefundDeadline(uint256 tokenId) public view returns (uint256) {
        if (hasRefunded[tokenId]) {
            return 0;
        }
        return refundEndTimestamps[tokenId];
    }

    function getRefundAmount(uint256 tokenId) public view returns(uint256) {
        if (hasRefunded[tokenId]) {
            return 0;
        }
        return mintPrice;
    }

    function withdraw() external onlyOwner {
        require(block.timestamp > refundEndTimestamp, "It's not past the refund period");
        uint256 balance = address(this).balance;
        Address.sendValue(payable(msg.sender), balance);
    }
}