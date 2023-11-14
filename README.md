# AdSystem Smart Contract

## Overview
The `AdSystem` smart contract is a conceptual implementation designed to manage and rotate advertisements in a blockchain environment. This contract includes features for requesting, queuing, and rotating ads, as well as managing ad durations and payments through an escrow system.

### Disclaimer
This contract is **not secure or optimized** for production use. It is intended as a conceptual demonstration and should be used for educational purposes only. Before deploying a similar contract in a live environment, extensive testing, security audits, and optimizations are necessary.

## Features
- **Ad Request**: Users can request to place ads by providing ad details and depositing the required amount based on the ad duration.
- **Ad Queue Management**: The contract owner can approve or reject ads. Approved ads are added to a queue.
- **Ad Rotation**: The contract includes a function to rotate ads, removing expired ads from active display and replacing them with queued ads.
- **Escrow System**: An escrow mechanism handles payments securely, providing a refund if an ad is not approved.

## Functions
1. `requestAd`: Request to place an ad.
2. `cancelAd`: Cancel a pending ad request.
3. `addAdToQueue`: Approve an ad and add it to the active queue.
4. `rejectAd`: Reject a pending ad request.
5. `rotateAds`: Rotate ads based on their expiration.
6. `setMaxActiveAds`: Set the maximum number of active ads.
7. `setMaxAdDuration`: Set the maximum duration for an ad.
8. `setHourlyPrice`: Set the hourly price for ad placement.
9. `getActiveAds`: Get the list of active ads.
10. `getQueuedAds`: Get the list of queued ads.
11. `getPendingAds`: Get the list of pending ads.

## Usage
To use this contract:
1. Deploy the `AdSystem` contract.
2. Set the escrow contract address using `setAdEscrow`.
3. Users can request ads using `requestAd`.
4. The contract owner manages ad requests via `addAdToQueue` or `rejectAd`.
5. Use `rotateAds` periodically to update the active ad display, should use chainlink instead tho

## Security and Optimization
- This contract has not been optimized for gas efficiency.
- Security measures