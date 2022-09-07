// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "hardhat/console.sol";

error VerifyFailed();
error IncorrectLevel(string expected, string actual);
error NotOwnerOfPosition();
error NotOwnerOfPlanetStructure();

contract BasicNft is ERC721, Ownable {
    using Strings for string;

    event MintedPlanet(
        address indexed owner
    );

    string public constant LEVEL = "0";

    string public constant TOKEN_URI =
        "ipfs://bafybeig37ioir76s7mg5oobetncojcm3c3hxasyd4rvid4jqhy4gkaheg4/?filename=0-PUG.json";
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

    constructor() ERC721("Planet XtaX", "XTAX") {
        s_tokenCounter = 0;
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
        }
        else {
            senderOwnsPosition = true;
        }

        bool senderOwnsStructure = false;

        // If structure is already owned
        if(planetStructureCIDToTokenId[planetStructureCID] != 0) {
            // If it is owned by a different Xtaxian
            if(tokenIdToInfo[planetStructureCIDToTokenId[planetStructureCID]].owner != msg.sender) {
                revert NotOwnerOfPlanetStructure();
            }
        }
        else {
            senderOwnsStructure = true;
        }

        if(senderOwnsStructure) {
            PlanetInfo memory info = tokenIdToInfo[planetStructureCIDToTokenId[planetStructureCID]];
            removePlanetFromPosition(msg.sender, 
                info.position,
                planetStructureCID,
                info.planetMetadataCID
            );
            tokenIdToBurn = planetStructureCIDToTokenId[planetStructureCID];
        }
        else if(senderOwnsPosition) {
            PlanetInfo memory info = tokenIdToInfo[positionToTokenId[positionStr]];
            removePlanetFromPosition(msg.sender, 
                positionStr, 
                info.planetStructureCID,
                info.planetMetadataCID
            );
            tokenIdToBurn = positionToTokenId[positionStr];
        }

        addPlanetToPosition(msg.sender, positionStr, planetStructureCID, planetMetadataCID);

        emit MintedPlanet(msg.sender);
    }

    function removePlanetFromPosition(address sender, string memory position, string memory planetStructureCID, string memory planetMetadataCID) internal {
        delete positionToPlanetMetadataCID[position];
        delete positionToPlanetStructureCID[position];
        delete positionToOwner[position];
        delete planetStructureCIDToPosition[planetStructureCID];
        delete planetStructureCIDToOwner[planetStructureCID];
        delete planetMetadataCIDToOwner[planetMetadataCID];
    }

    function addPlanetToPosition(address sender, string memory position, string memory planetStructureCID, string memory planetMetadataCID) internal {

        s_tokenCounter = s_tokenCounter + 1;
        _safeMint(msg.sender, s_tokenCounter);

        tokenIdToInfo[s_tokenCounter] = PlanetInfo(msg.sender, position, planetStructureCID, planetMetadataCID);

        positionToTokenId[position] = s_tokenCounter;
        planetStructureCIDToTokenId[planetStructureCID] = s_tokenCounter;
        planetMetadataCIDToTokenId[planetMetadataCID] = s_tokenCounter;
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
