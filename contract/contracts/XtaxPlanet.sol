// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./CircularBuffer.sol";

import "hardhat/console.sol";

/// @notice Error for signature does not match supplied planet info
/// @notice Error for public key is not a registered signer
error VerifyFailed();

/// @notice Error for planet is minted a level (vertical height) not supported by this contract
error IncorrectLevel(string expected, string actual);

/// @notice Error for no planet stored for a given position or CID
error PlanetNotFound();

/// @notice Error for attempt to change planet for which token id is not owned by the sender
error NotOwnerOfToken();

/// @notice Error for attempt to change planet when account other than sender owns planet at that location
error NotOwnerOfPosition();

/// @notice Error for attempt to change planet when account other than sender owns planet with that structure
error NotOwnerOfPlanetStructure();

/// @notice Error for attempt to change planet with not enough value supplied
error NotEnoughWei(uint expected, uint actual);

/// @title NFT for a Planet in the Planet Xtax universe
/// @author Ben Razor
contract XtaxPlanet is ERC721, Ownable {
    using Strings for string;

    /// @notice Emit when planet minted
    event MintedPlanet(
        address indexed owner,
        uint256 indexed tokenId,
        string indexed planetMetadataCID
    );

    /// @notice Emit when planet burned
    event BurnedPlanet(
        address indexed owner,
        uint256 indexed tokenId,
        string indexed planetMetadataCID
    );

    /// @notice Emit when planet transferred
    event TransferredPlanet(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId,
        string planetMetadataCID
    );

    /// @notice The level (vertical height) that planets can be created on on this blockchain
    string public constant LEVEL = "42";

    /// @notice Minimum value required to mint a planet
    uint public mintPrice = 1 ether;

    /// @notice Mid-range value for minting a planet
    uint public midMintPrice = 10 ether;

    /// @notice High value for minting a planet
    uint public highMintPrice = 100 ether;

    /// @notice Maximum value allowed for minting a planet
    uint public maxMintPrice = 1000 ether;

    /// @notice The standard NFT token counter
    uint256 private tokenCounter;

    /// @dev A set of addresses that are valid signers of submitted planet info
    mapping(address => bool) signers;

    /// @notice Stores the properties of owned planets
    struct PlanetInfo {
        address owner;
        string position;
        string planetStructureCID;
        string planetMetadataCID;
    }

    /// @notice Lookup tokenId by position
    mapping(string => uint256) public positionToTokenId;

    /// @notice Lookup tokenId by metadataCID
    mapping(string => uint256) public planetMetadataCIDToTokenId;

    /// @notice Lookup tokenId by structureCID
    mapping(string => uint256) planetStructureCIDToTokenId;

    /// @notice Lookup Planet info by tokenId
    mapping(uint256 => PlanetInfo) tokenIdToInfo;

    /// @notice A short buffer of recently created planets to allow simple searches
    uint8 public constant NUM_RECENT_CREATIONS = 8;

    /// @notice A circular buffer to store recently created planets
    mapping(address => CircularBuffer.Buf) ownerToRecentCreations;

    /**
     * @dev Initialize the the contract with the name and tokenId
     * @dev Add one signer that can be used to verify planet info signatures
     */
    constructor(address signer) ERC721("Planet XtaX Planet", "XTAX") {
        tokenCounter = 0;
        addSigner(signer);
    }

    /// @notice Get the URI for a given tokenId
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (tokenIdToInfo[tokenId].owner == address(0)) {
            revert PlanetNotFound();
        }

        return string(abi.encodePacked("ipfs://", tokenIdToInfo[tokenId].planetMetadataCID));
    }

    /// @notice Get the Planet info for a given tokenId
    function planetNFT(uint256 tokenId) external view returns (PlanetInfo memory) {
        return tokenIdToInfo[tokenId];
    }

    /// @notice Get the Planet info for a given position
    function positionToPlanetNFT(
        string calldata position
    ) external view returns (PlanetInfo memory) {
        return tokenIdToInfo[positionToTokenId[position]];
    }

    /// @notice Get the Planet info for given positions
    function positionsToPlanetNFTS(
        string[] calldata positions
    ) external view returns (PlanetInfo[] memory) {
        PlanetInfo[] memory planetInfos = new PlanetInfo[](positions.length);

        for (uint8 i = 0; i < positions.length; i++) {
            string memory position = positions[i];
            planetInfos[i] = tokenIdToInfo[positionToTokenId[position]];
        }

        return planetInfos;
    }

    /// @notice Get the Planet info for metadata CID
    function planetMetadataCIDToPlanetNFT(
        string calldata planetMetadataCID
    ) external view returns (PlanetInfo memory) {
        return tokenIdToInfo[planetMetadataCIDToTokenId[planetMetadataCID]];
    }

    /// @notice Get the current number of tokens created
    function getTokenCounter() external view returns (uint256) {
        return tokenCounter;
    }

    /// @dev Withdraw value stored in this contract to an address
    /// @dev Only the OWNER of the contract should be able to call this method
    function withdraw(address payable to, uint amount) external onlyOwner {
        if (amount > 0 && to != address(0)) {
            to.transfer(amount);
        }
    }

    /// @dev Change the minimum price to mint a planet
    /// @dev Only the OWNER of the contract should be able to call this method
    function setMintPrice(uint amount) external onlyOwner {
        mintPrice = amount;
    }

    /**
     * @dev Converts a string representation of a natural number to an integer.
     * @param str The string to convert.
     * @return The integer representation of the natural number.
     */
    function stringToNaturalInt(string memory str) public pure returns (uint256) {
        bytes memory strBytes = bytes(str);
        require(strBytes.length > 0, "Empty string");

        uint256 result = 0;

        for (uint256 i = 0; i < strBytes.length; i++) {
            uint8 digit = uint8(strBytes[i]);
            require(digit >= 48 && digit <= 57, "Invalid character");

            result = result * 10 + (digit - 48);
        }

        return result;
    }

    /**
     * @notice Mint a planet with given CIDs at a position
     * @notice Value of mintPrice must be provided
     * @notice Planet can only be minted on the valid level (vertical height) for this contract
     * @param position Must be not owned, or owned by the sender
     * @param planetStructureCID Must be not owned, or owned by the sender
     * @param signature The data planetMetadataCID:planetStructureCID:x,y,z must be signed by a signer registered by this contract
     */
    function mintPlanet(
        string calldata planetMetadataCID,
        string calldata planetStructureCID,
        string[] calldata position,
        bytes memory signature
    ) external payable {
        // If trying to mint on wrong level (vertical height not available on this blockchain)
        if (keccak256(abi.encodePacked(position[1])) != keccak256(abi.encodePacked(LEVEL))) {
            revert IncorrectLevel(LEVEL, position[1]);
        }

        uint256 x = stringToNaturalInt(position[0]);
        uint256 z = stringToNaturalInt(position[2]);

        console.log(x, z);
        if (x == 0 && z == 0) {
            if (msg.value < maxMintPrice) {
                revert NotEnoughWei(maxMintPrice, msg.value);
            }
        } else if (x < 3 && z < 3) {
            if (msg.value < highMintPrice) {
                revert NotEnoughWei(highMintPrice, msg.value);
            }
        } else if (x < 8 && z < 8) {
            if (msg.value < midMintPrice) {
                revert NotEnoughWei(midMintPrice, msg.value);
            }
        } else {
            if (msg.value < mintPrice) {
                revert NotEnoughWei(mintPrice, msg.value);
            }
        }

        string memory positionStr = string(
            abi.encodePacked(position[0], ",", position[1], ",", position[2])
        );

        if (!verify(planetMetadataCID, planetStructureCID, positionStr, signature)) {
            revert VerifyFailed();
        }

        uint256 tokenIdToBurn = 0;
        bool senderOwnsPosition = false;

        // If position already has planet
        if (positionToTokenId[positionStr] != 0) {
            // If it is owned by a different Xtaxian
            if (tokenIdToInfo[positionToTokenId[positionStr]].owner != msg.sender) {
                revert NotOwnerOfPosition();
            } else {
                senderOwnsPosition = true;
            }
        }

        bool senderOwnsStructure = false;

        // If structure is already owned
        if (planetStructureCIDToTokenId[planetStructureCID] != 0) {
            // If it is owned by a different Xtaxian
            if (
                tokenIdToInfo[planetStructureCIDToTokenId[planetStructureCID]].owner != msg.sender
            ) {
                revert NotOwnerOfPlanetStructure();
            } else {
                senderOwnsStructure = true;
            }
        }

        if (senderOwnsStructure) {
            uint256 tokenId = planetStructureCIDToTokenId[planetStructureCID];
            PlanetInfo memory info = tokenIdToInfo[tokenId];
            removePlanetFromPosition(
                info.position,
                planetStructureCID,
                info.planetMetadataCID,
                tokenId
            );
        } else if (senderOwnsPosition) {
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

    /**
     * @notice Burn the planet with a given planetMetadataCID
     * @notice Only owner may burn planet
     */
    function burnPlanet(string calldata planetMetadataCID) external {
        uint256 tokenId = planetMetadataCIDToTokenId[planetMetadataCID];

        if (tokenId == 0) {
            revert PlanetNotFound();
        }

        PlanetInfo memory info = tokenIdToInfo[tokenId];

        if (info.owner != msg.sender) {
            revert NotOwnerOfToken();
        }

        removePlanetFromPosition(
            info.position,
            info.planetStructureCID,
            info.planetMetadataCID,
            tokenId
        );
    }

    /**
     * @dev Internal method used remove a planet from a location if it has been burned or moved
     */
    function removePlanetFromPosition(
        string memory position,
        string memory planetStructureCID,
        string memory planetMetadataCID,
        uint256 tokenId
    ) internal {
        delete tokenIdToInfo[tokenId];
        delete positionToTokenId[position];
        delete planetStructureCIDToTokenId[planetStructureCID];
        delete planetMetadataCIDToTokenId[planetMetadataCID];

        removeFromRecentCreations(msg.sender, tokenId);

        emit BurnedPlanet(msg.sender, tokenCounter, planetMetadataCID);

        _burn(tokenId);
    }

    /**
     * @dev Internal method used add a planet to a position during minting
     */
    function addPlanetToPosition(
        string memory position,
        string memory planetStructureCID,
        string memory planetMetadataCID
    ) internal {
        tokenCounter = tokenCounter + 1;

        tokenIdToInfo[tokenCounter] = PlanetInfo(
            msg.sender,
            position,
            planetStructureCID,
            planetMetadataCID
        );

        positionToTokenId[position] = tokenCounter;
        planetStructureCIDToTokenId[planetStructureCID] = tokenCounter;
        planetMetadataCIDToTokenId[planetMetadataCID] = tokenCounter;

        addToRecentCreations(msg.sender, tokenCounter);

        console.log('msg send', msg.sender, tokenCounter, planetMetadataCID);
        emit MintedPlanet(msg.sender, tokenCounter, planetMetadataCID);

        _safeMint(msg.sender, tokenCounter);
    }

    /**
     * @notice Override of NFT transferFrom method
     */
    function transferFrom(address from, address to, uint256 tokenId) public override {
        _transferPlanet(from, to, tokenId);
        super.transferFrom(from, to, tokenId);
    }

    /**
     * @notice Override of NFT safeTransferFrom method
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) public override {
        _transferPlanet(from, to, tokenId);
        super.safeTransferFrom(from, to, tokenId);
    }

    /**
     * @notice Override of NFT safeTransferFrom with data method
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public override {
        _transferPlanet(from, to, tokenId);
        super.safeTransferFrom(from, to, tokenId, data);
    }

    /**
     * @notice Internal method to transfer planet between accounts
     */
    function _transferPlanet(address from, address to, uint256 tokenId) internal {
        PlanetInfo storage info = tokenIdToInfo[tokenId];

        info.owner = to;
        addToRecentCreations(to, tokenId);
        removeFromRecentCreations(from, tokenId);

        emit TransferredPlanet(from, to, tokenId, info.planetMetadataCID);
    }

    /**
     * @notice Internal method add tokenId to short list of recently added planets
     */
    function addToRecentCreations(address creator, uint256 tokenId) internal {
        if (ownerToRecentCreations[creator].numElems == 0) {
            ownerToRecentCreations[creator] = CircularBuffer.Buf(
                0,
                NUM_RECENT_CREATIONS,
                new uint256[](NUM_RECENT_CREATIONS)
            );
        }

        CircularBuffer.insert(ownerToRecentCreations[creator], tokenId);
    }

    /**
     * @notice Internal method remove tokenId to short list of recently added planets
     */
    function removeFromRecentCreations(address creator, uint256 tokenId) internal {
        if (ownerToRecentCreations[creator].numElems != 0) {
            for (uint8 i = 0; i < NUM_RECENT_CREATIONS; i++) {
                if (CircularBuffer.read(ownerToRecentCreations[creator], int8(i)) == tokenId) {
                    CircularBuffer.erase(ownerToRecentCreations[creator], int8(i));
                    break;
                }
            }
        }
    }

    /**
     * @notice Get a short list of recently added planet infos for this account
     */
    function recentPlanetsForAddress(address addr) external view returns (PlanetInfo[] memory) {
        PlanetInfo[] memory planetInfos = new PlanetInfo[](NUM_RECENT_CREATIONS);

        if (ownerToRecentCreations[addr].numElems != 0) {
            for (uint8 i = 0; i < NUM_RECENT_CREATIONS; i++) {
                uint256 tokenId = CircularBuffer.read(ownerToRecentCreations[addr], int8(i));
                planetInfos[i] = tokenIdToInfo[tokenId];
            }
        }

        return planetInfos;
    }

    /**
     * @dev Add a signer to validate submitted planet data
     * @dev Only the OWNER of the contract should be able to call this method
     */
    function addSigner(address signer) public onlyOwner {
        signers[signer] = true;
    }

    /**
     * @dev Verify planet data against a signature
     * @return false if signature is not valid for data, or if recovered address is not a registered signer
     */
    function verify(
        string calldata planetMetadataCID,
        string calldata planetStructureCID,
        string memory position,
        bytes memory signature
    ) public view returns (bool) {
        bytes32 msgHash = keccak256(
            abi.encodePacked(planetMetadataCID, ":", planetStructureCID, ":", position)
        );
        bytes32 msgFull = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", msgHash));
        address signer = this.recover(msgFull, signature);

        bool isSigner = signers[signer];

        return isSigner;
    }

    /**
     * @dev ECDSA recover helper method
     */
    function recover(bytes32 hash, bytes memory signature) external pure returns (address) {
        return ECDSA.recover(hash, signature);
    }
}
