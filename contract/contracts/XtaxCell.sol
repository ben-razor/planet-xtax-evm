// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./CircularBuffer.sol";

import "hardhat/console.sol";

/// @notice Error for signature does not match supplied cell info
/// @notice Error for public key is not a registered signer
error VerifyFailed();

/// @notice Error for no cell stored for a given id
error CellNotFound();

/// @notice Error for attempt to change cell for which token id is not owned by the sender
error NotOwnerOfToken();

/// @notice Error for attempt to change cell when account other than sender owns cell with those properties
error NotOwnerOfCell();

/// @notice Error for mint cell that is already owned
error AlreadyOwnerOfCell();

/// @notice Error for attempt to change planet with not enough value supplied
error NotEnoughWei(uint expected, uint actual);

/// @title NFT for a Cell in the Planet Xtax Universe
/// @author Ben Razor
contract XtaxCell is ERC721, Ownable {
    using Strings for string;

    /// @notice Emit when cell minted
    event MintedCell(
        address indexed owner,
        uint256 indexed tokenId,
        string indexed cellMetadataCID
    );

    /// @notice Emit when cell burned
    event BurnedCell(
        address indexed owner,
        uint256 indexed tokenId,
        string indexed cellMetadataCID
    );

    /// @notice Emit when cell transferred 
    event TransferredCell(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId,
        string cellMetadataCID
    );

    /// @notice Minimum value required to mint a cell 
    uint public mintPrice = 0.1 ether;

    /// @notice The standard NFT token counter
    uint256 private tokenCounter;

    /// @dev A set of addresses that are valid signers of submitted planet info
    mapping(address => bool) signers;

    /// @notice Stores the properties of owned cells 
    struct CellInfo {
        address owner;
        string cellMetadataCID;
    }

    /// @notice Lookup tokenId by metadataCID
    mapping(string => uint256) cellMetadataCIDToTokenId;


    /// @notice Lookup Cell info by tokenId
    mapping(uint256 => CellInfo) tokenIdToInfo;

    /// @notice A short buffer of recently created planets to allow simple searches
    uint8 public constant NUM_RECENT_CREATIONS = 8;

    /// @notice A circular buffer to store recently created planets
    mapping(address => CircularBuffer.Buf) ownerToRecentCreations;

    /**
     * @dev Initialize the the contract with the name and tokenId
     * @dev Add one signer that can be used to verify cell info signatures
     */
    constructor(address signer) ERC721("Planet XtaX Cell", "XTAXC") {
        tokenCounter = 0;
        addSigner(signer);
    }

    /// @notice Get the URI for a given tokenId
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if(tokenIdToInfo[tokenId].owner == address(0)) {
            revert CellNotFound();
        }

        return string(abi.encodePacked("ipfs://", tokenIdToInfo[tokenId].cellMetadataCID));
    }

    /// @notice Get the Cell info for a given tokenId
    function cellNFT(uint256 tokenId) external view returns (CellInfo memory) {
        return tokenIdToInfo[tokenId];
    }

    /// @notice Get the Cell info for metadata CID
    function cellMetadataCIDToCellNFT(string calldata cellMetadataCID) external view returns (CellInfo memory) {
        return tokenIdToInfo[cellMetadataCIDToTokenId[cellMetadataCID]];
    }

    /// @notice Get the current number of tokens created
    function getTokenCounter() external view returns (uint256) {
        return tokenCounter;
    }

    /// @dev Withdraw value stored in this contract to an address
    /// @dev Only the OWNER of the contract should be able to call this method
    function withdraw(address payable to, uint amount) external onlyOwner {
        if(amount > 0 && to != address(0)) {
            to.transfer(amount);
        }
    }

    /// @dev Change the minimum price to mint a planet
    /// @dev Only the OWNER of the contract should be able to call this method
    function setMintPrice(uint amount) external onlyOwner {
        mintPrice = amount;
    }

    /**
     * @notice Mint a cell with given CID
     * @notice Value of mintPrice must be provided 
     * @param cellMetadataCID Must be not owned, or owned by the sender
     * @param signature The cellMetadataCID must be signed by a signer registered by this contract
     */
    function mintCell(
        string calldata cellMetadataCID, 
        bytes memory signature
    ) external payable {

        if(msg.value < mintPrice) {
            revert NotEnoughWei(mintPrice, msg.value);
        }

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

    /**
     * @notice Burn the cell with a given cellMetadataCID
     * @notice Only owner may burn cell 
     */
    function burnCell(string calldata cellMetadataCID) external {
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

    /**
     * @dev Internal method to burn cell and remove cell specific data
     */
    function removeCell(string memory cellMetadataCID, uint256 tokenId) internal {
        delete tokenIdToInfo[tokenId];
        delete cellMetadataCIDToTokenId[cellMetadataCID];

        removeFromRecentCreations(msg.sender, tokenId);

        emit BurnedCell(msg.sender, tokenCounter, cellMetadataCID);

        _burn(tokenId);
    }

    /*
     * Internal method to mint cell and store cell specific data
     */
    function addCell(string memory cellMetadataCID) internal {

        tokenCounter = tokenCounter + 1;
        tokenIdToInfo[tokenCounter] = CellInfo(msg.sender, cellMetadataCID);

        cellMetadataCIDToTokenId[cellMetadataCID] = tokenCounter;

        addToRecentCreations(msg.sender, tokenCounter);

        emit MintedCell(msg.sender, tokenCounter, cellMetadataCID);

        _safeMint(msg.sender, tokenCounter);
    }

    /**
     * @notice Override of NFT transferFrom method
     */
    function transferFrom(address from, address to, uint256 tokenId) public override {
        _transferCell(from, to, tokenId);
        super.transferFrom(from, to, tokenId);
    }

    /**
     * @notice Override of NFT safeTransferFrom method
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) public override {
        _transferCell(from, to, tokenId);
        super.safeTransferFrom(from, to, tokenId);
    }

    /**
     * @notice Override of NFT safeTransferFrom with data method
     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public override {
        _transferCell(from, to, tokenId);
        super.safeTransferFrom(from, to, tokenId, data);
    }

    /**
     * @notice Internal method to transfer cell between accounts
     */
    function _transferCell(address from, address to, uint256 tokenId) internal {
        CellInfo storage info = tokenIdToInfo[tokenId];

        info.owner = to;
        addToRecentCreations(to, tokenId);
        removeFromRecentCreations(from, tokenId);

        emit TransferredCell(from, to, tokenId, info.cellMetadataCID);
    }

    /**
     * @notice Internal method add tokenId to short list of recently added cells 
     */
    function addToRecentCreations(address creator, uint256 tokenId) internal {
        if(ownerToRecentCreations[creator].numElems == 0) {
            ownerToRecentCreations[creator] = CircularBuffer.Buf(0, NUM_RECENT_CREATIONS, new uint256[](NUM_RECENT_CREATIONS));
        }

        CircularBuffer.insert(ownerToRecentCreations[creator], tokenId);
    }

    /**
     * @notice Internal method remove tokenId to short list of recently added cells 
     */
    function removeFromRecentCreations(address creator, uint256 tokenId) internal {
        if(ownerToRecentCreations[creator].numElems !=  0) {
            for(uint8 i = 0; i < NUM_RECENT_CREATIONS; i++) {
                if(CircularBuffer.read(ownerToRecentCreations[creator], int8(i)) == tokenId) {
                    CircularBuffer.erase(ownerToRecentCreations[creator], int8(i));
                    break;
                }
            }
        }
    }

    /**
     * @notice Get a short list of recently added cell infos for this account
     */
    function recentCellsForAddress(address addr) external view returns(CellInfo[] memory) {
        CellInfo[] memory cellInfos = new CellInfo[](NUM_RECENT_CREATIONS);

        if(ownerToRecentCreations[addr].numElems !=  0) {
            for(uint8 i = 0; i < NUM_RECENT_CREATIONS; i++) {
                uint256 tokenId = CircularBuffer.read(ownerToRecentCreations[addr], int8(i));
                cellInfos[i] = tokenIdToInfo[tokenId];
            }
        }

        return cellInfos;
    }

    /**
     * @dev Add a signer to validate submitted cell data
     * @dev Only the OWNER of the contract should be able to call this method
     */
    function addSigner(address signer) public onlyOwner {
        signers[signer] = true;
    }

    /**
     * @dev Verify cell CID data against a signature
     * @return false if signature is not valid for data, or if recovered address is not a registered signer
     */
    function verify(
        string calldata cellMetadataCID, 
        bytes memory signature
    ) internal view returns(bool) {

        bytes32 msgHash = keccak256(abi.encodePacked(cellMetadataCID));
        bytes32 msgFull = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", msgHash));
        address signer = recover(msgFull, signature);

        bool isSigner = signers[signer];

        return isSigner;
    }

    /**
     * @dev ECDSA recover helper method
     */
    function recover(bytes32 hash, bytes memory signature) internal pure returns(address) {
        return ECDSA.recover(hash, signature);
    }
}

