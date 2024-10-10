// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;



import { IMarketplace, IHandles, IBicForwarder } from "./common/Interfaces.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title HandlesController
 * @dev Manages operations related to handle auctions and direct handle requests, including minting and claim payouts.
 * Uses ECDSA for signature verification and integrates with a marketplace for auction functionalities.
 */
contract HandlesController is Initializable, UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using ECDSA for bytes32;
    /**
     * @notice Represents the configuration of an auction marketplace, including the buyout bid amount, time buffer, and bid buffer.
     * @dev Represents the configuration of an auction marketplace, including the buyout bid amount, time buffer, and bid buffer.
     */
    struct AuctionConfig {
        uint256 buyoutBidAmount;
        uint64 timeBufferInSeconds;
        uint64 bidBufferBps;
    }

    enum MintType {
        DIRECT,
        COMMIT,
        AUCTION
    }

    /**
     * @dev Represents a request to create a handle, either through direct sale or auction.
     */
    struct HandleRequest {
        address receiver; // Address to receive the handle.
        address handle; // Contract address of the handle.
        string name; // Name of the handle.
        uint256 price; // Price to be paid for the handle.
        address[] beneficiaries; // Beneficiaries for the handle's payment.
        uint256[] collects; // Shares of the proceeds for each beneficiary.
        uint256 commitDuration; // Duration for which the handle creation can be committed (reserved).
        bool isAuction; // Indicates if the handle request is for an auction.
    }

    struct HandlesControllerStorage {
        address verifier;
        IERC20 bic;
        IMarketplace marketplace;
        IBicForwarder forwarder;
        uint256 collectsDenominator;
        address collector;
        AuctionConfig auctionConfig;
        mapping(bytes32 => uint256) commitments;
        mapping(uint256 => bool) auctionCanClaim;
    }
    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.HandlesController")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant HandlesControllerStorageLocation = 0xdb8c6c955e53b2f2aa6af3f6dc6cde534c8d38ac14789e36f0795e74e216e300;

    function _getHandlesControllerStorage() private pure returns (HandlesControllerStorage storage $) {
        assembly {
            $.slot := HandlesControllerStorageLocation
        }
    }


    event MintHandle(
        address indexed handle,
        address indexed to,
        string name,
        uint256 price,
        MintType mintType
    );
    /// @dev Emitted when a commitment is made, providing details of the commitment and its expiration timestamp.
    event Commitment(
        bytes32 indexed commitment,
        address from,
        address collection,
        string name,
        uint256 tokenId,
        uint256 price,
        uint256 endTimestamp,
        bool isClaimed
    );
    /// @dev Emitted when a handle is minted, providing details of the transaction including the handle address, recipient, name, and price.
    event ShareRevenue(
        address from,
        address to,
        uint256 amount
    );
    /// @dev Emitted when the verifier address is updated.
    event SetVerifier(address indexed verifier);
    /// @dev Emitted when the forwarder address is updated.
    event SetForwarder(address indexed forwarder);
    /// @dev Emitted when the marketplace address is updated.
    event SetMarketplace(address indexed marketplace);
    /// @dev Emmitted when the auction marketplace configuration is updated.
    event SetAuctionMarketplace(AuctionConfig _newConfig);
    /// @dev Emitted when an auction is created, providing details of the auction ID.
    event CreateAuction(uint256 auctionId);
    /// @dev Emitted when a handle is minted but the auction fails due none bid.
    event BurnHandleMintedButAuctionFailed(
        address handle,
        string name,
        uint256 tokenId
    );

    /**
     * @notice Initializes the HandlesController contract with the given BIC token address.
     */
    function initialize(IERC20 _bic, address _owner) public initializer {
        __Ownable_init(_owner);
        __ReentrancyGuard_init();
        

        AuctionConfig memory auctionConfig = AuctionConfig({
            buyoutBidAmount: 0,
            timeBufferInSeconds: 900,
            bidBufferBps: 1000
        });

        HandlesControllerStorage storage $ = _getHandlesControllerStorage();
        $.bic = _bic;
        $.auctionConfig = auctionConfig;
        $.collectsDenominator = 10000;

    }

    function _authorizeUpgrade(address) internal override onlyOwner { }

    function verifier() external view returns (address) {
        HandlesControllerStorage storage $ = _getHandlesControllerStorage();
        return $.verifier;
    }

    function marketplace() external view returns (address) {
        HandlesControllerStorage storage $ = _getHandlesControllerStorage();
        return address($.marketplace);
    }

    /**
     * @notice Sets a new verifier address authorized to validate signatures.
     * @dev Can only be set by an operator. Emits a SetVerifier event upon success.
     * @param _verifier The new verifier address.
     */
    function setVerifier(address _verifier) external onlyOwner {
        HandlesControllerStorage storage $ = _getHandlesControllerStorage();
        $.verifier = _verifier;
        emit SetVerifier(_verifier);
    }

    /**
     * @notice Sets the marketplace contract address used for handling auctions.
     * @dev Can only be set by an operator. Emits a SetMarketplace event upon success.
     * @param _marketplace The address of the Thirdweb Marketplace contract.
     */
    function setMarketplace(address _marketplace) external onlyOwner {
        HandlesControllerStorage storage $ = _getHandlesControllerStorage();
        $.marketplace = IMarketplace(_marketplace);
        emit SetMarketplace(_marketplace);
    }

    /**
     * @notice Sets the configuration of the auction marketplace.
     * @dev Can only be set by an operator. Emits a SetMarketplace event upon success.
     * @param _newConfig configuration of the auction marketplace
     */
    function setAuctionMarketplaceConfig(
        AuctionConfig memory _newConfig
    ) external onlyOwner {
        require(
            _newConfig.timeBufferInSeconds > 0,
            "HandlesController: timeBufferInSeconds must be greater than 0"
        );
        require(
            _newConfig.bidBufferBps > 0,
            "HandlesController: bidBufferBps must be greater than 0"
        );
        //
        require(
            _newConfig.bidBufferBps <= 10_000,
            "HandlesController: bidBufferBps must be less than 10_000"
        );

        HandlesControllerStorage storage $ = _getHandlesControllerStorage();
        $.auctionConfig = _newConfig;
        emit SetAuctionMarketplace(_newConfig);
    }

    /**
     * @notice Updates the denominator used for calculating beneficiary shares.
     * @dev Can only be performed by an operator. This is used to adjust the precision of distributions.
     * @param _collectsDenominator The new denominator value for share calculations.
     */
    function updateCollectsDenominator(
        uint256 _collectsDenominator
    ) external onlyOwner {
        HandlesControllerStorage storage $ = _getHandlesControllerStorage();
        $.collectsDenominator = _collectsDenominator;
    }

    /**
     * @notice Sets the address of the collector, who receives any residual funds not distributed to beneficiaries.
     * @dev Can only be performed by an operator. This address acts as a fallback for undistributed funds.
     * @param _collector The address of the collector.
     */
    function setCollector(address _collector) external onlyOwner {
        HandlesControllerStorage storage $ = _getHandlesControllerStorage();
        $.collector = _collector;
    }

    /**
     * @notice Sets the forwarder contract address used for handling interactions with the BIC token.
     * @dev Can only be set by an operator. Emits a SetForwarder event upon success.
     * @dev Using to help controller can bid in auction on behalf of a user want to mint handle but end up in case auction.
     * @param _forwarder The address of the BIC forwarder contract.
     */
    function setForwarder(address _forwarder) external onlyOwner {
        HandlesControllerStorage storage $ = _getHandlesControllerStorage();
        $.forwarder = IBicForwarder(_forwarder);
        emit SetForwarder(_forwarder);
    }    

    
}
