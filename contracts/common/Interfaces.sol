// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';



/// @title A Handles interface for creating and interacting with handles
/// @dev Details about handles can be found in the Handles contract
interface IHandles is IERC721 {

    function mintHandle(address to, string calldata localName) external returns (uint256);

    function burn(uint256 tokenId) external;

    function getNamespace() external view returns (string memory);

    function getNamespaceHash() external view returns (bytes32);

    function exists(uint256 tokenId) external view returns (bool);

    function getLocalName(uint256 tokenId) external view returns (string memory);

    function getHandle(uint256 tokenId) external view returns (string memory);

    function getTokenId(string memory localName) external pure returns (uint256);

    function totalSupply() external view returns (uint256);

    function setController(address controller) external;

    function getHandleTokenURIContract() external view returns (address);

    function setHandleTokenURIContract(address handleTokenURIContract) external;
}

interface IBicForwarder {
    event Requested(address indexed controller, address indexed from, address indexed to, bytes data, uint256 value);
    struct RequestData {
        address from;
        address to;
        bytes data;
        uint256 value;
    }

    function forwardRequest(RequestData memory requestData) external;
}

interface IMarketplace {
    struct AuctionParameters {
        address assetContract;
        uint256 tokenId;
        uint256 quantity;
        address currency;
        uint256 minimumBidAmount;
        uint256 buyoutBidAmount;
        uint64 timeBufferInSeconds;
        uint64 bidBufferBps;
        uint64 startTimestamp;
        uint64 endTimestamp;
    }

    function createAuction(AuctionParameters calldata _params) external returns (uint256 auctionId);

    function bidInAuction(uint256 _auctionId, uint256 _bidAmount) external payable;

    enum Status {
        UNSET,
        CREATED,
        COMPLETED,
        CANCELLED
    }

    enum TokenType {
        ERC721,
        ERC1155
    }

    struct Auction {
        uint256 auctionId;
        uint256 tokenId;
        uint256 quantity;
        uint256 minimumBidAmount;
        uint256 buyoutBidAmount;
        uint64 timeBufferInSeconds;
        uint64 bidBufferBps;
        uint64 startTimestamp;
        uint64 endTimestamp;
        address auctionCreator;
        address assetContract;
        address currency;
        TokenType tokenType;
        Status status;
    }


}
