// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./CircularBuffer.sol";

import "hardhat/console.sol";

error VerifyFailed();
error IncorrectLevel(string expected, string actual);
error PlanetNotFound();
error NotOwnerOfToken();
error NotOwnerOfPosition();
error NotOwnerOfPlanetStructure();

contract BasicNft is ERC721, Ownable {
    using Strings for string;

    event MintedPlanet(
        address indexed owner,
        uint256 indexed tokenId,
        string indexed planetMetadataCID
    );

    event BurnedPlanet(
        address indexed owner,
        uint256 indexed tokenId,
        string indexed planetMetadataCID
    );

    uint8 public constant NUM_RECENT_CREATIONS = 8;
    string public constant LEVEL = "0";

    uint256 private s_tokenCounter;

    mapping(address => bool) signers;

    struct PlanetInfo {
        address owner;
        string position;
        string planetStructureCID;
        string planetMetadataCID;
    }

    mapping(string => uint256) positionToTokenId;
    mapping(string => uint256) planetMetadataCIDToTokenId;
    mapping(string => uint256) planetStructureCIDToTokenId;

    mapping(uint256 => PlanetInfo) tokenIdToInfo;

    mapping(string => address) positionToOwner;
    mapping(string => address) planetStructureCIDToOwner;
    mapping(string => address) planetMetadataCIDToOwner;
    mapping(string => string) planetStructureCIDToPosition;
    mapping(string => string) positionToPlanetMetadataCID;
    mapping(string => string) positionToPlanetStructureCID;

    mapping(address => CircularBuffer.Buf) ownerToRecentCreations;

    constructor() ERC721("Planet XtaX", "XTAX") {
        s_tokenCounter = 0;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(tokenIdToInfo[tokenId].owner != address(0), "ERC721Metadata: URI query for nonexistent token");

        return string(abi.encodePacked("ipfs://", tokenIdToInfo[tokenId].planetMetadataCID));
    }

    function planetNFT(uint256 tokenId) public view returns (PlanetInfo memory) {
        return tokenIdToInfo[tokenId];
    }

    function positionToPlanetNFT(string calldata position) public view returns (PlanetInfo memory) {
        return tokenIdToInfo[positionToTokenId[position]];
    }

    function planetMetadataCIDToPlanetNFT(string calldata planetMetadataCID) public view returns (PlanetInfo memory) {
        return tokenIdToInfo[planetMetadataCIDToTokenId[planetMetadataCID]];
    }

    function getTokenCounter() public view returns (uint256) {
        return s_tokenCounter;
    }

    function mintPlanet(
        string calldata planetMetadataCID, 
        string calldata planetStructureCID, 
        string[] calldata position,
        bytes memory signature
    ) public returns(address) {

        // If trying to mint on wrong level (vertical height not available on this blockchain)
        if(keccak256(abi.encodePacked(position[1])) != keccak256(abi.encodePacked(LEVEL))) {
            revert IncorrectLevel(position[1], LEVEL);
        }

        string memory positionStr = string(abi.encodePacked(position[0],",",position[1],",",position[2]));

        if(!verify(planetMetadataCID, planetStructureCID, positionStr, signature)) {
            revert VerifyFailed();
        }

        uint256 tokenIdToBurn = 0;
        bool senderOwnsPosition = false;
        
        // If position already has planet
        if(positionToTokenId[positionStr] != 0) {
            // If it is owned by a different Xtaxian
            if(tokenIdToInfo[positionToTokenId[positionStr]].owner != msg.sender) {
                revert NotOwnerOfPosition();
            }
            else {
                senderOwnsPosition = true;
            }
        }

        bool senderOwnsStructure = false;

        // If structure is already owned
        if(planetStructureCIDToTokenId[planetStructureCID] != 0) {
            // If it is owned by a different Xtaxian
            if(tokenIdToInfo[planetStructureCIDToTokenId[planetStructureCID]].owner != msg.sender) {
                revert NotOwnerOfPlanetStructure();
            }
            else {
                senderOwnsStructure = true;
            }
        }

        if(senderOwnsStructure) {
            uint256 tokenId = planetStructureCIDToTokenId[planetStructureCID];
            PlanetInfo memory info = tokenIdToInfo[tokenId];
            removePlanetFromPosition(msg.sender, 
                info.position,
                planetStructureCID,
                info.planetMetadataCID,
                tokenId
            );
        }
        else if(senderOwnsPosition) {
            uint256 tokenId = positionToTokenId[positionStr];
            PlanetInfo memory info = tokenIdToInfo[tokenId];
            removePlanetFromPosition(msg.sender, 
                positionStr, 
                info.planetStructureCID,
                info.planetMetadataCID,
                tokenId
            );
            tokenIdToBurn = positionToTokenId[positionStr];
        }

        addPlanetToPosition(msg.sender, positionStr, planetStructureCID, planetMetadataCID);
    }

    function burnPlanet(string calldata planetMetadataCID) public {
        uint256 tokenId = planetMetadataCIDToTokenId[planetMetadataCID];
        
        if(tokenId == 0) {
            revert PlanetNotFound();
        }

        PlanetInfo memory info = tokenIdToInfo[tokenId];

        if(info.owner != msg.sender) {
            revert NotOwnerOfToken();
        }

        removePlanetFromPosition(msg.sender, info.position, info.planetStructureCID, info.planetMetadataCID, tokenId);
    }

    function removePlanetFromPosition(address sender, string memory position, string memory planetStructureCID, string memory planetMetadataCID, uint256 tokenId) internal {
        _burn(tokenId);

        delete tokenIdToInfo[tokenId];
        delete positionToTokenId[position];
        delete planetStructureCIDToTokenId[planetStructureCID];
        delete planetMetadataCIDToTokenId[planetMetadataCID];

        removeFromRecentCreations(sender, tokenId);

        emit BurnedPlanet(msg.sender, s_tokenCounter, planetMetadataCID);
    }

    function addPlanetToPosition(address sender, string memory position, string memory planetStructureCID, string memory planetMetadataCID) internal {

        s_tokenCounter = s_tokenCounter + 1;
        _safeMint(msg.sender, s_tokenCounter);

        tokenIdToInfo[s_tokenCounter] = PlanetInfo(msg.sender, position, planetStructureCID, planetMetadataCID);

        positionToTokenId[position] = s_tokenCounter;
        planetStructureCIDToTokenId[planetStructureCID] = s_tokenCounter;
        planetMetadataCIDToTokenId[planetMetadataCID] = s_tokenCounter;

        addToRecentCreations(msg.sender, s_tokenCounter);

        emit MintedPlanet(msg.sender, s_tokenCounter, planetMetadataCID);
    }

    function addToRecentCreations(address sender, uint256 tokenId) internal {
        if(ownerToRecentCreations[sender].numElems == 0) {
            ownerToRecentCreations[sender] = CircularBuffer.Buf(0, NUM_RECENT_CREATIONS, new uint256[](NUM_RECENT_CREATIONS));
        }

        CircularBuffer.insert(ownerToRecentCreations[sender], s_tokenCounter);
    }

    function removeFromRecentCreations(address sender, uint256 tokenId) internal {
        for(uint8 i = 0; i < NUM_RECENT_CREATIONS; i++) {
            if(CircularBuffer.read(ownerToRecentCreations[sender], i) == tokenId) {
                CircularBuffer.erase(ownerToRecentCreations[sender], i);
                break;
            }
        }
    }

    function recentTokenIdsForAddress(address sender) public view returns(uint256[] memory) {
        uint256[] memory recentCreations = new uint256[](NUM_RECENT_CREATIONS);

        for(uint8 i = 0; i < NUM_RECENT_CREATIONS; i++) {
            recentCreations[i] = CircularBuffer.read(ownerToRecentCreations[sender], i);
        }

        return recentCreations;
    }

    function addSigner(address signer) public onlyOwner {
        signers[signer] = true;
    }

    function verify(
        string calldata planetMetadataCID, 
        string calldata planetStructureCID, 
        string memory position,
        bytes memory signature
    ) public view returns(bool) {

        bytes32 msgHash = keccak256(abi.encodePacked(planetMetadataCID, ":", planetStructureCID, ":", position));
        bytes32 msgFull = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", msgHash));
        address signer = this.recover(msgFull, signature);

        bool isSigner = signers[signer];

        return isSigner;
    }

    function recover(bytes32 hash, bytes memory signature) public pure returns(address) {
        return ECDSA.recover(hash, signature);
    }

}

