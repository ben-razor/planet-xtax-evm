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
    mapping(string => address) positionToOwner;
    mapping(string => address) planetStructureCIDToOwner;
    mapping(string => string) planetStructureCIDToPosition;
    mapping(string => string) positionToPlanetMetadataCID;
    mapping(string => string) positionToPlanetStructureCID;

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
        string[] calldata position,
        bytes memory signature
    ) public returns(address) {

        bool isCorrectLevel = keccak256(abi.encodePacked(position[1])) == keccak256(abi.encodePacked(LEVEL));

        if(!isCorrectLevel) {
            revert IncorrectLevel(position[1], LEVEL);
        }

        string memory positionStr = string(abi.encodePacked(position[0],",",position[1],",",position[2]));

        if(!verify(planetMetadataCID, planetStructureCID, positionStr, signature)) {
            revert VerifyFailed();
        }

        string memory tokenIdToBurn = "";
        bool senderOwnsPosition = false;

        // If position already has planet
        if(positionToOwner[positionStr] != address(0)) {
            // If it is owned by a different XtaXian
            if(positionToOwner[positionStr] != msg.sender) {
                revert NotOwnerOfPosition();
            }
        }
        else {
            senderOwnsPosition = true;
        }

        bool senderOwnsStructure = false;

        // If structure is already owned
        if(planetStructureCIDToOwner[positionStr] != address(0)) {
            // If it is owned by a different XtaXian
            if(planetStructureCIDToOwner[positionStr] != msg.sender) {
                revert NotOwnerOfPlanetStructure();
            }
        }
        else {
            senderOwnsStructure = true;
        }

        if(senderOwnsStructure) {
            string memory oldPosition = planetStructureCIDToPosition[planetStructureCID];
            string memory oldPlanetMetadataCID = positionToPlanetMetadataCID[oldPosition];
            removePlanetFromPosition(msg.sender, 
                oldPosition, 
                planetStructureCID, 
                oldPlanetMetadataCID
            );
            tokenIdToBurn = oldPlanetMetadataCID;
        }
        else if(senderOwnsPosition) {
            string memory oldPlanetStructureCID = positionToPlanetStructureCID[positionStr];
            string memory oldPlanetMetadataCID = positionToPlanetMetadataCID[positionStr];
            removePlanetFromPosition(msg.sender, positionStr, oldPlanetStructureCID, oldPlanetMetadataCID);
            tokenIdToBurn = oldPlanetMetadataCID;
        }


        emit MintedPlanet(msg.sender);
    }

    function removePlanetFromPosition(address sender, string memory position, string memory planetStructureCID, string memory planetMetadataCID) internal {

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
