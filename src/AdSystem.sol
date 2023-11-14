/// @title AdSystem for Managing and Displaying Ads
/// @author 0xOrphan
/// @notice This contract allows for the creation, management, and display of ads
/// @dev This contract interacts with AdEscrow for payment handling

//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AdEscrow} from "./AdEscrow.sol";


import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AdEscrow} from "./AdEscrow.sol";

error IndexOutOfBounds(uint256 index);
error OverMaxActiveAds(uint8 maxActiveAds);
error UnderActiveAds(uint8 maxActiveAds);
error NotAdvertiser(address advertiser);
error AdDoesNotExist(uint256 adIndex);
error AdDurationTooShort(uint256 maxAdDuration);
error AdDurationTooLong(uint256 maxAdDuration);
error FailedToDeposit(uint256 amount);
error FailedToRelease(uint256 amount);
error InsufficientBalance(uint256 balance, uint256 amount);
error EscrowNotSet();

contract AdSystem is Ownable, ReentrancyGuard {
    AdEscrow public adEscrow;

    struct Ad {
        string title;
        string description;
        string website;
        string adImage;
        uint256 hoursRequested;
        uint256 expirationTimestamp;
        address advertiser;
    }

    uint8 public maxActiveAds;
    uint256 public maxHoursPerAd;
    uint256 public hourlyPrice;

    Ad[] private activeAds;
    Ad[] private queuedAds;
    Ad[] private pendingAds;

    event AdRequested(
        string title,
        string description,
        string website,
        string adImage,
        uint256 hoursRequested,
        uint256 expirationTimestamp,
        address advertiser
    );
    event AdQueued(
        string title,
        string description,
        string website,
        string adImage,
        uint256 hoursRequested,
        uint256 expirationTimestamp,
        address advertiser
    );
    event AdRejected(
        string title,
        string description,
        string website,
        string adImage,
        uint256 hoursRequested,
        uint256 expirationTimestamp,
        address advertiser
    );
    event AdCancelled(
        string title,
        string description,
        string website,
        string adImage,
        uint256 hoursRequested,
        uint256 expirationTimestamp,
        address advertiser
    );
    event AdExpired(
        string title,
        string description,
        string website,
        string adImage,
        uint256 hoursRequested,
        uint256 expirationTimestamp,
        address advertiser
    );
    event AdRemoved(
        string title,
        string description,
        string website,
        string adImage,
        uint256 hoursRequested,
        uint256 expirationTimestamp,
        address advertiser
    );
    event HourlyPriceChanged(uint256 hourlyPrice);
    event MaxActiveAdsChanged(uint8 maxActiveAds);
    event MaxAdDurationChanged(uint256 maxAdDuration);

    constructor(uint8 _maxActiveAds, uint256 _maxHoursPerAd, uint256 _hourlyPrice, address _owner) Ownable(_owner) {
        maxActiveAds = _maxActiveAds;
        maxHoursPerAd = _maxHoursPerAd;
        hourlyPrice = _hourlyPrice;
    }

    modifier escrowMustBeSet() {
        if (address(adEscrow) == address(0)) revert EscrowNotSet();
        _;
    }

    function requestAd(
        string memory _title,
        string memory _description,
        string memory _website,
        string memory _adImage,
        uint8 _adHours
    ) public payable escrowMustBeSet nonReentrant {
        if (_adHours > maxHoursPerAd) revert AdDurationTooLong(_adHours);
        if (_adHours < 1) revert AdDurationTooShort(_adHours);
        uint256 adCost = getCostForAd(_adHours);
        if (msg.value < adCost) revert InsufficientBalance(msg.value, adCost);

        Ad memory ad = Ad({
            title: _title,
            description: _description,
            website: _website,
            adImage: _adImage,
            hoursRequested: _adHours,
            expirationTimestamp: 0,
            advertiser: msg.sender
        });

        pendingAds.push(ad);
        adEscrow.deposit{value: adCost}(adCost, msg.sender);
        emit AdRequested(_title, _description, _website, _adImage, _adHours, 0, msg.sender);
    }

    function rotateAds() public onlyOwner {
        uint256 timestamp = block.timestamp;

        for (uint256 i = activeAds.length; i > 0; i--) {
            uint256 index = i - 1;
            Ad memory ad = activeAds[index];
            if (ad.expirationTimestamp < timestamp) {
                emit AdExpired(ad.title, ad.description, ad.website, ad.adImage, ad.hoursRequested, ad.expirationTimestamp, ad.advertiser);
                if (index != activeAds.length - 1) {
                    activeAds[index] = activeAds[activeAds.length - 1];
                }
                activeAds.pop();
            }
        }
        while (activeAds.length < maxActiveAds && queuedAds.length > 0) {
            Ad memory ad = queuedAds[0];
            ad.expirationTimestamp = (uint256(ad.hoursRequested) * 1 hours) + timestamp;
            activeAds.push(ad);
            emit AdQueued(ad.title, ad.description, ad.website, ad.adImage, ad.hoursRequested, ad.expirationTimestamp, ad.advertiser);
            for (uint256 i = 0; i < queuedAds.length - 1; i++) {
                queuedAds[i] = queuedAds[i + 1];
            }
            queuedAds.pop();
        }
    }

    function cancelAd(uint256 _index) public escrowMustBeSet nonReentrant {
        if (_index > pendingAds.length) revert IndexOutOfBounds(_index);
        Ad memory ad = pendingAds[_index];
        address advertiser = ad.advertiser;
        if (msg.sender != advertiser) revert NotAdvertiser(msg.sender);
        for (uint256 i = _index; i < pendingAds.length - 1; i++) {
            pendingAds[i] = pendingAds[i + 1];
        }
        pendingAds.pop();
        adEscrow.refundPayment(payable(advertiser));
        emit AdCancelled(ad.title, ad.description, ad.website, ad.adImage, ad.hoursRequested, ad.expirationTimestamp, advertiser);
    }

    function addAdToQueue(uint256 _adIndex) public onlyOwner escrowMustBeSet nonReentrant {
        if (_adIndex > pendingAds.length) revert IndexOutOfBounds(_adIndex);
        Ad memory ad = pendingAds[_adIndex];
        address advertiser = ad.advertiser;
        queuedAds.push(ad);
        for (uint256 i = _adIndex; i < pendingAds.length - 1; i++) {
            pendingAds[i] = pendingAds[i + 1];
        }
        pendingAds.pop();
        adEscrow.releasePayment(advertiser);
        emit AdQueued(ad.title, ad.description, ad.website, ad.adImage, ad.hoursRequested, ad.expirationTimestamp, advertiser);
    }

    function rejectAd(uint256 _adIndex) public onlyOwner escrowMustBeSet nonReentrant {
        if (_adIndex > pendingAds.length) revert IndexOutOfBounds(_adIndex);
        Ad memory ad = pendingAds[_adIndex];
        address advertiser = ad.advertiser;
        for (uint256 i = _adIndex; i < pendingAds.length - 1; i++) {
            pendingAds[i] = pendingAds[i + 1];
        }
        pendingAds.pop();
        adEscrow.refundPayment(payable(advertiser));
        emit AdRejected(ad.title, ad.description, ad.website, ad.adImage, ad.hoursRequested, ad.expirationTimestamp, advertiser);
    }

    function setAdEscrow(address _adEscrow) public onlyOwner {
        if (_adEscrow == address(0)) revert EscrowNotSet();
        adEscrow = AdEscrow(_adEscrow);
    }

    function setMaxActiveAds(uint8 _maxActiveAds) public onlyOwner {
        if (_maxActiveAds < type(uint8).max) revert OverMaxActiveAds(_maxActiveAds);
        if (_maxActiveAds > activeAds.length) revert UnderActiveAds(_maxActiveAds);
        maxActiveAds = _maxActiveAds;
        emit MaxActiveAdsChanged(_maxActiveAds);
    }

    function setMaxAdDuration(uint256 _maxAdDurationInHours) public onlyOwner {
        if (_maxAdDurationInHours < 1) revert AdDurationTooShort(_maxAdDurationInHours);
        if (_maxAdDurationInHours > type(uint256).max) revert AdDurationTooLong(_maxAdDurationInHours);
        maxHoursPerAd = _maxAdDurationInHours;
        emit MaxAdDurationChanged(_maxAdDurationInHours);
    }

    function setHourlyPrice(uint256 _hourlyPrice) public onlyOwner {
        hourlyPrice = _hourlyPrice;
        emit HourlyPriceChanged(_hourlyPrice);
    }

    function getActiveAds() public view returns (Ad[] memory) {
        return activeAds;
    }

    function getActiveAdByIndex(uint256 _index) public view returns (Ad memory) {
        if (_index > activeAds.length) revert AdDoesNotExist(_index);
        return activeAds[_index];
    }

    function getQueuedAds() public view returns (Ad[] memory) {
        return queuedAds;
    }

    function getQueuedAdByIndex(uint256 _index) public view returns (Ad memory) {
        if (_index > queuedAds.length) revert AdDoesNotExist(_index);
        return queuedAds[_index];
    }

    function getPendingAds() public view returns (Ad[] memory) {
        return pendingAds;
    }

    function getPendingAdByIndex(uint256 _index) public view returns (Ad memory) {
        if (_index > pendingAds.length) revert AdDoesNotExist(_index);
        return pendingAds[_index];
    }

    function getCostForAd(uint256 _adHours) public view returns (uint256) {
        return _adHours * hourlyPrice;
    }

    function getAdEscrowAddress() public view returns (address) {
        return address(adEscrow);
    }
}
