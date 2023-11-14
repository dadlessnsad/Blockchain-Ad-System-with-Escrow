// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Test, console2} from "forge-std/Test.sol";
import {AdSystem} from "../src/AdSystem.sol";
import {AdEscrow} from "../src/AdEscrow.sol";

contract AdSystemTest is Test {
    AdSystem public adSystem;
    AdEscrow public adEscrow;

    struct Ad {
        string title;
        string description;
        string website;
        string adImage;
        uint256 expirationTimestamp;
        address advertiser;
    }

    address public owner;
    address public payoutAddress;
    address public alice;
    address public bob;
    address public carol;
    address public dan;
    address public eve;
    address public frank;

    function setUp() public {
        owner = address(this);
        payoutAddress = address(0x11);
        alice = address(0x1);
        bob = address(0x2);
        carol = address(0x3);
        dan = address(0x4);
        eve = address(0x5);
        frank = address(0x6);

        vm.startPrank(owner);
        adSystem = new AdSystem(
                3,
                48,
                0.1 ether,
                address(owner)
            );

        adEscrow = new AdEscrow(address(payoutAddress), address(adSystem));

        adSystem.setAdEscrow(address(adEscrow));
        vm.stopPrank();

        vm.deal(owner, 10 ether);
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(carol, 10 ether);
        vm.deal(dan, 10 ether);
        vm.deal(eve, 10 ether);
        vm.deal(frank, 10 ether);
    }

    function testDeploy() public {
        assertEq(adSystem.maxActiveAds(), 3);
        assertEq(adSystem.maxHoursPerAd(), 48);
        assertEq(adSystem.hourlyPrice(), 0.1 ether);
        assertEq(adSystem.owner(), owner);
        assertEq(adSystem.getAdEscrowAddress(), address(adEscrow));
        assertEq(adEscrow.payoutAddress(), address(payoutAddress));
    }

    // @notice:     Test That a user can request an ad
    // @dev:        Test that the ad is added to the pending ads
    // @dev:        Test that the user's balance is updated
    // @dev:        Test that the escrow balance is updated
    function testSingleAdRequest() public {
        uint256 adCost = adSystem.getCostForAd(24);
        vm.startPrank(alice);
        adSystem.requestAd{value: adCost}(
            "Test Add",
            "This is a test add, please ignore",
            "https://www.google.com",
            "https://www.google.com/images/branding/googlelogo/1x/googlelogo_color_272x92dp.png",
            24
        );
        uint256 escrowBalance = adEscrow.escrowBalance();
        assertEq(escrowBalance, adCost);
        vm.stopPrank();
        uint256 aliceBalance = adEscrow.checkAddressBalance(alice);
        assertEq(aliceBalance, adCost);
        AdSystem.Ad memory ad = adSystem.getPendingAdByIndex(0);
        assertEq(ad.title, "Test Add");
        assertEq(ad.description, "This is a test add, please ignore");
        assertEq(ad.website, "https://www.google.com");
        assertEq(ad.adImage, "https://www.google.com/images/branding/googlelogo/1x/googlelogo_color_272x92dp.png");
        assertEq(ad.hoursRequested, 24);
        assertEq(ad.expirationTimestamp, 0);
        assertEq(ad.advertiser, alice);
    }

    // @notice:     Test That Owner of contract can approve a requested ad
    // @dev:        Test that the ad is added to the queuedAds array
    // @dev:        Test that the user's balance is updated && the escrow balance is updated && payout address balance is updated
    function testAddAdToQueryArray() public {
        uint256 adCost = adSystem.getCostForAd(24);
        vm.startPrank(alice);
        adSystem.requestAd{value: adCost}(
            "Test Add",
            "This is a test add, please ignore",
            "https://www.google.com",
            "https://www.google.com/images/branding/googlelogo/1x/googlelogo_color_272x92dp.png",
            24
        );
        uint256 escrowBalance = adEscrow.escrowBalance();
        assertEq(escrowBalance, adCost);
        vm.stopPrank();
        uint256 aliceBalance = adEscrow.checkAddressBalance(alice);
        assertEq(aliceBalance, adCost);
        AdSystem.Ad memory ad = adSystem.getPendingAdByIndex(0);
        assertEq(ad.title, "Test Add");
        assertEq(ad.description, "This is a test add, please ignore");
        assertEq(ad.website, "https://www.google.com");
        assertEq(ad.adImage, "https://www.google.com/images/branding/googlelogo/1x/googlelogo_color_272x92dp.png");
        assertEq(ad.hoursRequested, 24);
        assertEq(ad.expirationTimestamp, 0);
        assertEq(ad.advertiser, alice);

        vm.startPrank(owner);
        adSystem.addAdToQueue(0);
        vm.stopPrank();

        ad = adSystem.getQueuedAdByIndex(0);
        assertEq(ad.title, "Test Add");
        assertEq(ad.description, "This is a test add, please ignore");
        assertEq(ad.website, "https://www.google.com");
        assertEq(ad.adImage, "https://www.google.com/images/branding/googlelogo/1x/googlelogo_color_272x92dp.png");
        assertEq(ad.hoursRequested, 24);
        assertEq(ad.expirationTimestamp, 0);
        assertEq(ad.advertiser, alice);

        aliceBalance = adEscrow.checkAddressBalance(alice);
        assertEq(aliceBalance, 0);
        // address of payout address
        uint256 payoutBalance = address(payoutAddress).balance;
        assertEq(payoutBalance, adCost);
    }

    function testCancelRequestedAd() public {
        uint256 adCost = adSystem.getCostForAd(24);
        vm.startPrank(alice);
        adSystem.requestAd{value: adCost}(
            "Test Add",
            "This is a test add, please ignore",
            "https://www.google.com",
            "https://www.google.com/images/branding/googlelogo/1x/googlelogo_color_272x92dp.png",
            24
        );
        uint256 escrowBalance = adEscrow.escrowBalance();
        assertEq(escrowBalance, adCost);
        uint256 aliceBalance = adEscrow.checkAddressBalance(alice);
        assertEq(aliceBalance, adCost);
        AdSystem.Ad memory ad = adSystem.getPendingAdByIndex(0);
        assertEq(ad.title, "Test Add");
        assertEq(ad.description, "This is a test add, please ignore");
        assertEq(ad.website, "https://www.google.com");
        assertEq(ad.adImage, "https://www.google.com/images/branding/googlelogo/1x/googlelogo_color_272x92dp.png");
        assertEq(ad.hoursRequested, 24);
        assertEq(ad.expirationTimestamp, 0);
        assertEq(ad.advertiser, alice);

        adSystem.cancelAd(0);
        aliceBalance = adEscrow.checkAddressBalance(alice);
        assertEq(aliceBalance, 0);

        vm.stopPrank();
    }

    function testRejectAdd() public {
        uint256 aliceOrgBalance = address(alice).balance;
        uint256 adCost = adSystem.getCostForAd(24);
        vm.startPrank(alice);
        adSystem.requestAd{value: adCost}(
            "Test Add",
            "This is a test add, please ignore",
            "https://www.google.com",
            "https://www.google.com/images/branding/googlelogo/1x/googlelogo_color_272x92dp.png",
            24
        );
        uint256 escrowBalance = adEscrow.escrowBalance();
        assertEq(escrowBalance, adCost);
        vm.stopPrank();
        uint256 aliceBalance = adEscrow.checkAddressBalance(alice);
        assertEq(aliceBalance, adCost);
        AdSystem.Ad memory ad = adSystem.getPendingAdByIndex(0);
        assertEq(ad.title, "Test Add");
        assertEq(ad.description, "This is a test add, please ignore");
        assertEq(ad.website, "https://www.google.com");

        vm.startPrank(owner);
        adSystem.rejectAd(0);
        vm.stopPrank();

        aliceBalance = adEscrow.checkAddressBalance(alice);
        assertEq(aliceBalance, 0);
        assertEq(address(alice).balance, aliceOrgBalance);
        // address of payout address
        uint256 payoutBalance = address(payoutAddress).balance;
        assertEq(payoutBalance, 0);
    }

    function testRotateAds() public {
        uint256 adCost = adSystem.getCostForAd(24);
        vm.startPrank(alice);
        adSystem.requestAd{value: adCost}(
            "Test Add",
            "This is a test add, please ignore",
            "https://www.google.com",
            "https://www.google.com/images/branding/googlelogo/1x/googlelogo_color_272x92dp.png",
            24
        );
        vm.stopPrank();
        uint256 aliceBalance = adEscrow.checkAddressBalance(alice);
        assertEq(aliceBalance, adCost);
        vm.startPrank(bob);
        adSystem.requestAd{value: adCost}(
            "Test Add 2",
            "This is a test add, please ignore",
            "https://www.google.com",
            "https://www.google.com/images/branding/googlelogo/1x/googlelogo_color_272x92dp.png",
            24
        );
        vm.stopPrank();
        uint256 bobBalance = adEscrow.checkAddressBalance(bob);
        assertEq(bobBalance, adCost);
        vm.startPrank(carol);
        adSystem.requestAd{value: adCost}(
            "Test Add 3",
            "This is a test add, please ignore",
            "https://www.google.com",
            "https://www.google.com/images/branding/googlelogo/1x/googlelogo_color_272x92dp.png",
            24
        );
        vm.stopPrank();
        uint256 carolBalance = adEscrow.checkAddressBalance(carol);
        assertEq(carolBalance, adCost);
        vm.startPrank(dan);
        adSystem.requestAd{value: adCost}(
            "Test Add 4",
            "This is a test add, please ignore",
            "https://www.google.com",
            "https://www.google.com/images/branding/googlelogo/1x/googlelogo_color_272x92dp.png",
            24
        );
        vm.stopPrank();
        uint256 danBalance = adEscrow.checkAddressBalance(dan);
        assertEq(danBalance, adCost);
        vm.startPrank(eve);
        adSystem.requestAd{value: adCost}(
            "Test Add 5",
            "This is a test add, please ignore",
            "https://www.google.com",
            "https://www.google.com/images/branding/googlelogo/1x/googlelogo_color_272x92dp.png",
            24
        );
        vm.stopPrank();
        uint256 eveBalance = adEscrow.checkAddressBalance(eve);
        assertEq(eveBalance, adCost);
        vm.startPrank(frank);
        adSystem.requestAd{value: adCost}(
            "Test Add 6",
            "This is a test add, please ignore",
            "https://www.google.com",
            "https://www.google.com/images/branding/googlelogo/1x/googlelogo_color_272x92dp.png",
            24
        );
        vm.stopPrank();
        uint256 frankBalance = adEscrow.checkAddressBalance(frank);
        assertEq(frankBalance, adCost);
        vm.startPrank(owner);
        adSystem.addAdToQueue(0);
        adSystem.addAdToQueue(0);
        adSystem.addAdToQueue(0);
        adSystem.addAdToQueue(0);
        adSystem.addAdToQueue(0);
        adSystem.addAdToQueue(0);

        assertEq(address(payoutAddress).balance, adCost * 6);
        adSystem.rotateAds();
        adSystem.getQueuedAds();
        adSystem.getActiveAds();

        uint256 futureTimeStamp = block.timestamp + 25 hours;
        vm.warp(futureTimeStamp);
        adSystem.rotateAds();
        adSystem.getQueuedAds();
        adSystem.getActiveAds();

        vm.stopPrank();
    }
}
