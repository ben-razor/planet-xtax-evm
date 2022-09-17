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
error NotEnoughWei(uint expected, uint actual);

contract XtaxPlanet is ERC721, Ownable {
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

    event TransferredPlanet(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId,
        string planetMetadataCID
    );

    uint8 public constant NUM_RECENT_CREATIONS = 8;
    string public constant LEVEL = "42";

    uint public mintPrice = 1 ether;

    uint256 private s_tokenCounter;

    mapping(address => bool) signers;

    struct PlanetInfo {
        address owner;
        string position;
        string planetStructureCID;
        string planetMetadataCID;
    }

    mapping(string => uint256) public positionToTokenId;
    mapping(string => uint256) public planetMetadataCIDToTokenId;
    mapping(string => uint256) planetStructureCIDToTokenId;

    mapping(uint256 => PlanetInfo) tokenIdToInfo;
    mapping(address => CircularBuffer.Buf) ownerToRecentCreations;

    constructor(address signer) ERC721("Planet XtaX Planet", "XTAX") {
        s_tokenCounter = 0;
        addSigner(signer);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if(tokenIdToInfo[tokenId].owner == address(0)) {
            revert PlanetNotFound();
        }

        return string(abi.encodePacked("ipfs://", tokenIdToInfo[tokenId].planetMetadataCID));
    }

    function planetNFT(uint256 tokenId) public view returns (PlanetInfo memory) {
        return tokenIdToInfo[tokenId];
    }

    function positionToPlanetNFT(string calldata position) public view returns (PlanetInfo memory) {
        return tokenIdToInfo[positionToTokenId[position]];
    }

    function positionsToPlanetNFTS(string[] calldata positions) public view returns(PlanetInfo[] memory) {
        PlanetInfo[] memory planetInfos = new PlanetInfo[](positions.length);

        for(uint8 i = 0; i < positions.length; i++) {
            string memory position = positions[i];
            planetInfos[i] = tokenIdToInfo[positionToTokenId[position]];
        }

        return planetInfos;
    }

    function planetMetadataCIDToPlanetNFT(string calldata planetMetadataCID) public view returns (PlanetInfo memory) {
        return tokenIdToInfo[planetMetadataCIDToTokenId[planetMetadataCID]];
    }

    function getTokenCounter() public view returns (uint256) {
        return s_tokenCounter;
    }

    function withdraw(address payable to, uint amount) public onlyOwner {
        to.transfer(amount);
    }

    function setMintPrice(uint amount) public onlyOwner {
        mintPrice = amount;
    }

    function mintPlanet(
        string calldata planetMetadataCID, 
        string calldata planetStructureCID, 
        string[] calldata position,
        bytes memory signature
    ) public payable {

        if(msg.value < mintPrice) {
            revert NotEnoughWei(mintPrice, msg.value);
        }

        // If trying to mint on wrong level (vertical height not available on this blockchain)
        if(keccak256(abi.encodePacked(position[1])) != keccak256(abi.encodePacked(LEVEL))) {
            revert IncorrectLevel(LEVEL, position[1]);
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
            removePlanetFromPosition(
                info.position,
                planetStructureCID,
                info.planetMetadataCID,
                tokenId
            );
        }
        else if(senderOwnsPosition) {
            uint256 tokenId = positionToTokenId[positionStr];
            PlanetInfo memory info = tokenIdToInfo[tokenId];
            removePlanetFromPosition(
                positionStr, 
                info.planetStructureCID,
                info.planetMetadataCID,
                tokenId
            );
            tokenIdToBurn = positionToTokenId[positionStr];
        }

        addPlanetToPosition(positionStr, planetStructureCID, planetMetadataCID);
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

        removePlanetFromPosition(info.position, info.planetStructureCID, info.planetMetadataCID, tokenId);
    }

    function removePlanetFromPosition(string memory position, string memory planetStructureCID, string memory planetMetadataCID, uint256 tokenId) internal {
        _burn(tokenId);

        delete tokenIdToInfo[tokenId];
        delete positionToTokenId[position];
        delete planetStructureCIDToTokenId[planetStructureCID];
        delete planetMetadataCIDToTokenId[planetMetadataCID];

        removeFromRecentCreations(msg.sender, tokenId);

        emit BurnedPlanet(msg.sender, s_tokenCounter, planetMetadataCID);
    }

    function addPlanetToPosition(string memory position, string memory planetStructureCID, string memory planetMetadataCID) internal {

        s_tokenCounter = s_tokenCounter + 1;
        _safeMint(msg.sender, s_tokenCounter);

        tokenIdToInfo[s_tokenCounter] = PlanetInfo(msg.sender, position, planetStructureCID, planetMetadataCID);

        positionToTokenId[position] = s_tokenCounter;
        planetStructureCIDToTokenId[planetStructureCID] = s_tokenCounter;
        planetMetadataCIDToTokenId[planetMetadataCID] = s_tokenCounter;

        addToRecentCreations(msg.sender, s_tokenCounter);

        emit MintedPlanet(msg.sender, s_tokenCounter, planetMetadataCID);
    }

    function transferFrom(address from, address to, uint256 tokenId) public override {
        super.transferFrom(from, to, tokenId);
        _transferPlanet(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public override {
        super.safeTransferFrom(from, to, tokenId);
        _transferPlanet(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public override {
        super.safeTransferFrom(from, to, tokenId, data);
        _transferPlanet(from, to, tokenId);
    }

    function _transferPlanet(address from, address to, uint256 tokenId) internal {
        PlanetInfo storage info = tokenIdToInfo[tokenId];

        info.owner = to;
        addToRecentCreations(to, tokenId);
        removeFromRecentCreations(from, tokenId);

        emit TransferredPlanet(from, to, tokenId, info.planetMetadataCID);
    }

    function addToRecentCreations(address owner, uint256 tokenId) internal {
        if(ownerToRecentCreations[owner].numElems == 0) {
            ownerToRecentCreations[owner] = CircularBuffer.Buf(0, NUM_RECENT_CREATIONS, new uint256[](NUM_RECENT_CREATIONS));
        }

        CircularBuffer.insert(ownerToRecentCreations[owner], tokenId);
    }

    function removeFromRecentCreations(address owner, uint256 tokenId) internal {
        if(ownerToRecentCreations[owner].numElems !=  0) {
            for(uint8 i = 0; i < NUM_RECENT_CREATIONS; i++) {
                if(CircularBuffer.read(ownerToRecentCreations[owner], int8(i)) == tokenId) {
                    CircularBuffer.erase(ownerToRecentCreations[owner], int8(i));
                    break;
                }
            }
        }
    }

    function recentPlanetsForAddress(address owner) public view returns(PlanetInfo[] memory) {
        PlanetInfo[] memory planetInfos = new PlanetInfo[](NUM_RECENT_CREATIONS);

        if(ownerToRecentCreations[owner].numElems !=  0) {
            for(uint8 i = 0; i < NUM_RECENT_CREATIONS; i++) {
                uint256 tokenId = CircularBuffer.read(ownerToRecentCreations[owner], int8(i));
                planetInfos[i] = tokenIdToInfo[tokenId];
            }
        }

        return planetInfos;
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

