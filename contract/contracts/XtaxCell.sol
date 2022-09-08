// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./CircularBuffer.sol";

import "hardhat/console.sol";

error VerifyFailed();
error IncorrectLevel(string expected, string actual);
error CellNotFound();
error NotOwnerOfToken();
error NotOwnerOfCell();
error AlreadyOwnerOfCell();

contract XtaxCell is ERC721, Ownable {
    using Strings for string;

    event MintedCell(
        address indexed owner,
        uint256 indexed tokenId,
        string indexed cellMetadataCID
    );

    event BurnedCell(
        address indexed owner,
        uint256 indexed tokenId,
        string indexed cellMetadataCID
    );

    uint8 public constant NUM_RECENT_CREATIONS = 8;
    string public constant LEVEL = "0";

    uint256 private s_tokenCounter;

    mapping(address => bool) signers;

    struct CellInfo {
        address owner;
        string cellMetadataCID;
    }

    mapping(string => uint256) cellMetadataCIDToTokenId;

    mapping(uint256 => CellInfo) tokenIdToInfo;

    mapping(address => CircularBuffer.Buf) ownerToRecentCreations;

    constructor() ERC721("XtaX Cell", "XTAXC") {
        s_tokenCounter = 0;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(tokenIdToInfo[tokenId].owner != address(0), "ERC721Metadata: URI query for nonexistent token");

        return string(abi.encodePacked("ipfs://", tokenIdToInfo[tokenId].cellMetadataCID));
    }

    function cellNFT(uint256 tokenId) public view returns (CellInfo memory) {
        return tokenIdToInfo[tokenId];
    }

    function cellMetadataCIDToCellNFT(string calldata cellMetadataCID) public view returns (CellInfo memory) {
        return tokenIdToInfo[cellMetadataCIDToTokenId[cellMetadataCID]];
    }

    function getTokenCounter() public view returns (uint256) {
        return s_tokenCounter;
    }

    function mintCell(
        string calldata cellMetadataCID, 
        bytes memory signature
    ) public returns(address) {

        if(!verify(cellMetadataCID, signature)) {
            revert VerifyFailed();
        }

        // If structure is already owned
        if(cellMetadataCIDToTokenId[cellMetadataCID] != 0) {
            // If it is owned by a different Xtaxian
            if(tokenIdToInfo[cellMetadataCIDToTokenId[cellMetadataCID]].owner != msg.sender) {
                revert NotOwnerOfCell();
            }
            else {
                revert AlreadyOwnerOfCell();
            }
        }

        addCell(msg.sender, cellMetadataCID);
    }

    function burnCell(string calldata cellMetadataCID) public {
        uint256 tokenId = cellMetadataCIDToTokenId[cellMetadataCID];
        
        if(tokenId == 0) {
            revert CellNotFound();
        }

        CellInfo memory info = tokenIdToInfo[tokenId];

        if(info.owner != msg.sender) {
            revert NotOwnerOfToken();
        }

        removeCell(msg.sender, info.cellMetadataCID, tokenId);
    }

    function removeCell(address sender, string memory cellMetadataCID, uint256 tokenId) internal {
        _burn(tokenId);

        delete tokenIdToInfo[tokenId];
        delete cellMetadataCIDToTokenId[cellMetadataCID];

        removeFromRecentCreations(sender, tokenId);

        emit BurnedCell(msg.sender, s_tokenCounter, cellMetadataCID);
    }

    function addCell(address sender, string memory cellMetadataCID) internal {

        s_tokenCounter = s_tokenCounter + 1;
        _safeMint(msg.sender, s_tokenCounter);

        tokenIdToInfo[s_tokenCounter] = CellInfo(msg.sender, cellMetadataCID);

        cellMetadataCIDToTokenId[cellMetadataCID] = s_tokenCounter;

        addToRecentCreations(msg.sender, s_tokenCounter);

        emit MintedCell(msg.sender, s_tokenCounter, cellMetadataCID);
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
        string calldata cellMetadataCID, 
        bytes memory signature
    ) public view returns(bool) {

        bytes32 msgHash = keccak256(abi.encodePacked(cellMetadataCID));
        bytes32 msgFull = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", msgHash));
        address signer = recover(msgFull, signature);

        bool isSigner = signers[signer];

        return isSigner;
    }

    function recover(bytes32 hash, bytes memory signature) internal pure returns(address) {
        return ECDSA.recover(hash, signature);
    }

}

