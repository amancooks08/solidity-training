// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MortgageContract {
    address public lender;
    address public borrower;

    uint public loanAmount;
    uint public interestRate;
    uint public loanDuration; // in months

    uint public monthlyPayment;
    uint public remainingPayments;

    // Events to track contract events
    event PaymentMade(uint amount);
    event LoanPaidOff();

    // Constructor to initialize the contract
    constructor(
        address _lender,
        address _borrower,
        uint _loanAmount,
        uint _interestRate,
        uint _loanDuration
    ) {
        lender = _lender;
        borrower = _borrower;
        loanAmount = _loanAmount;
        interestRate = _interestRate;
        loanDuration = _loanDuration;

        // Calculate monthly payment
        monthlyPayment = calculateMonthlyPayment();
        remainingPayments = _loanDuration;
    }

    // Function to calculate monthly payment based on loan details
    function calculateMonthlyPayment() internal view returns (uint) {
        // Simplified monthly payment calculation
        uint monthlyInterest = (loanAmount * interestRate) / (12 * 100);
        uint totalPayment = loanAmount + (monthlyInterest * loanDuration);
        return totalPayment / loanDuration;
    }

    // Function to make monthly payments
    function makeMonthlyPayment() external payable {
        require(msg.sender == borrower, "Only the borrower can make payments");
        require(msg.value == monthlyPayment, "Incorrect payment amount");

        // Decrease remaining payments
        remainingPayments--;

        // Emit event
        emit PaymentMade(msg.value);

        // Check if the loan is paid off
        if (remainingPayments == 0) {
            emit LoanPaidOff();
        }
    }
}
