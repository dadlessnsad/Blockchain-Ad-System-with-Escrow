// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

error IncorrectDepositAmount(uint256 msgValue, uint256 amount);
error InsufficientBalance(uint256 balance, uint256 amount);
error OnlyAdSystem(address adSystem);

contract AdEscrow is ReentrancyGuard {
    address public payoutAddress;
    address public adSystem;
    mapping(address => uint256) public escrowBalances;

    event Deposit(address indexed from, uint256 amount);
    event ReleasePayment(address indexed to, uint256 amount);
    event RefundPayment(address indexed to, uint256 amount);

    constructor(address _payoutAddress, address _adSystem) {
        payoutAddress = _payoutAddress;
        adSystem = _adSystem;
    }

    modifier onlyAdSystem() {
        if (msg.sender != adSystem) revert OnlyAdSystem(msg.sender);
        _;
    }

    function deposit(uint256 _amount, address _advitiser) external payable onlyAdSystem nonReentrant returns (bool) {
        if (msg.value != _amount) revert IncorrectDepositAmount(msg.value, _amount);
        escrowBalances[_advitiser] += _amount;
        emit Deposit(_advitiser, _amount);
        return true;
    }

    function releasePayment(address _advitiser) external onlyAdSystem nonReentrant returns (bool) {
        uint256 amount = escrowBalances[_advitiser];
        escrowBalances[_advitiser] -= amount;
        payable(payoutAddress).transfer(amount);
        emit ReleasePayment(payoutAddress, amount);
        return true;
    }

    function refundPayment(address payable _advitiser) external onlyAdSystem nonReentrant returns (bool) {
        uint256 amount = escrowBalances[_advitiser];
        escrowBalances[_advitiser] -= amount;
        (bool success,) = _advitiser.call{value: amount}("");
        require(success, "Transfer failed.");
        emit RefundPayment(_advitiser, amount);
        return true;
    }

    function escrowBalance() public view returns (uint256) {
        return escrowBalances[msg.sender];
    }

    function checkAddressBalance(address _address) public view returns (uint256) {
        return escrowBalances[_address];
    }
}
