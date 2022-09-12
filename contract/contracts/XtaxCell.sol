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

    event TransferredCell(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId,
        string cellMetadataCID
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

    constructor(address signer) ERC721("Planet XtaX Cell", "XTAXC") {
        s_tokenCounter = 0;
        addSigner(signer);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if(tokenIdToInfo[tokenId].owner == address(0)) {
            revert CellNotFound();
        }

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
    ) public {

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

        addCell(cellMetadataCID);
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

        removeCell(info.cellMetadataCID, tokenId);
    }

    function removeCell(string memory cellMetadataCID, uint256 tokenId) internal {
        _burn(tokenId);

        delete tokenIdToInfo[tokenId];
        delete cellMetadataCIDToTokenId[cellMetadataCID];

        removeFromRecentCreations(tokenId);

        emit BurnedCell(msg.sender, s_tokenCounter, cellMetadataCID);
    }

    function addCell(string memory cellMetadataCID) internal {

        s_tokenCounter = s_tokenCounter + 1;
        _safeMint(msg.sender, s_tokenCounter);

        tokenIdToInfo[s_tokenCounter] = CellInfo(msg.sender, cellMetadataCID);

        cellMetadataCIDToTokenId[cellMetadataCID] = s_tokenCounter;

        addToRecentCreations(s_tokenCounter);

        emit MintedCell(msg.sender, s_tokenCounter, cellMetadataCID);
    }

    function transferFrom(address from, address to, uint256 tokenId) public override {
        super.transferFrom(from, to, tokenId);

        CellInfo memory info = tokenIdToInfo[tokenId];

        emit TransferredCell(from, to, tokenId, info.cellMetadataCID);
    }

    function addToRecentCreations(uint256 tokenId) internal {
        if(ownerToRecentCreations[msg.sender].numElems == 0) {
            ownerToRecentCreations[msg.sender] = CircularBuffer.Buf(0, NUM_RECENT_CREATIONS, new uint256[](NUM_RECENT_CREATIONS));
        }

        CircularBuffer.insert(ownerToRecentCreations[msg.sender], tokenId);
    }

    function removeFromRecentCreations(uint256 tokenId) internal {
        if(ownerToRecentCreations[msg.sender].numElems !=  0) {
            for(uint8 i = 0; i < NUM_RECENT_CREATIONS; i++) {
                if(CircularBuffer.read(ownerToRecentCreations[msg.sender], int8(i)) == tokenId) {
                    CircularBuffer.erase(ownerToRecentCreations[msg.sender], int8(i));
                    break;
                }
            }
        }
    }

    function recentCellsForAddress(address owner) public view returns(CellInfo[] memory) {
        CellInfo[] memory cellInfos = new CellInfo[](NUM_RECENT_CREATIONS);

        if(ownerToRecentCreations[owner].numElems !=  0) {
            for(uint8 i = 0; i < NUM_RECENT_CREATIONS; i++) {
                uint256 tokenId = CircularBuffer.read(ownerToRecentCreations[owner], int8(i));
                cellInfos[i] = tokenIdToInfo[tokenId];
            }
        }

        return cellInfos;
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

