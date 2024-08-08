// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface ILottery {
    function buy(uint16 guess) external payable;

    function draw() external;

    function claim() external;

    function winningNumber() external view returns (uint16);

    struct Round {
        uint sellPhaseLimit;
        uint16 winningNumber;
        uint nWinners;
    }
    struct Ticket {
        uint roundId;
        uint16 guess;
    }
    enum Phase {
        Sell,
        Claim
    }
}

contract Lottery is ILottery {
    // [roundId][guess][user] => Ticket[]
    mapping(uint16 => mapping(address => Ticket[]))[] userTicketRecords;
    Round[] rounds;

    constructor() {
        rounds.push(Round(block.timestamp + 24 hours, 0, 0));
    }

    modifier phase(Phase p) {
        if (p == Phase.Sell) {
            require(block.timestamp < _getCurrentRound().sellPhaseLimit);
        } else if (p == Phase.Claim) {
            require(block.timestamp >= _getCurrentRound().sellPhaseLimit);
        } else {
            revert("Invalid phase");
        }
        _;
    }

    // ================== ILottery ==================

    function buy(uint16 guess) external payable override phase(Phase.Sell) {}

    function draw() external override phase(Phase.Claim) {}

    function claim() external override phase(Phase.Claim) {}

    function winningNumber() public view override returns (uint16) {
        return _getCurrentRound().winningNumber;
    }

    // ================== Internal ==================

    function _getRoundId() internal view returns (uint) {
        return rounds.length - 1;
    }

    function _getCurrentRound() internal view returns (Round storage) {
        return rounds[_getRoundId()];
    }

    function _getUsersTickets(
        uint16 guess
    ) internal view returns (Ticket[] storage) {
        return userTicketRecords[_getRoundId()][guess][msg.sender];
    }
}
