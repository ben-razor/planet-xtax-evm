// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "hardhat/console.sol";

contract BasicNft is ERC721, Ownable {
    string public constant TOKEN_URI =
        "ipfs://bafybeig37ioir76s7mg5oobetncojcm3c3hxasyd4rvid4jqhy4gkaheg4/?filename=0-PUG.json";
    uint256 private s_tokenCounter;

    constructor() ERC721("Planet XtaX", "XTAX") {
        s_tokenCounter = 0;
    }

    function mintNft() public onlyOwner {
        s_tokenCounter = s_tokenCounter + 1;
        _safeMint(msg.sender, s_tokenCounter);
    }

    function tokenURI(uint256 tokenId) public pure override returns (string memory) {
        // require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return TOKEN_URI;
    }

    function getTokenCounter() public view returns (uint256) {
        return s_tokenCounter;
    }

    function mintPlanet(
        string calldata planetMetadataCID, 
        string calldata planetStructureCID, 
        string calldata position,
        bytes memory signature
    ) public view returns(address) {
        bytes memory msg1 = abi.encodePacked(planetMetadataCID, ":", planetStructureCID, ":", position);

        bytes32 msgHash = keccak256("a:b:c");
        bytes32 msgFull = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", msgHash));
        address signer = this.recover(msgFull, signature);

        console.logBytes(signature);

        return signer;
    }

    function recover(bytes32 hash, bytes memory signature) public pure returns(address) {
        return ECDSA.recover(hash, signature);
    }

}
