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
    }
    struct Ticket {
        address owner;
        uint16 guess;
    }
    enum Phase {
        Sell,
        Draw,
        Claim
    }
}

contract Lottery is ILottery {
    uint constant TICKET_PRICE = 0.1 ether;
    uint constant PHASE_LENGTH = 24 hours;

    mapping(address => uint) rewards;
    Round round;
    uint16 public winningNumber;

    // ===============| Phase Temporary Dynamics |================

    Ticket[] tickets; // multi struct
    mapping(address => mapping(uint16 => bool))[] isPurchased; // deletable mapping
    mapping(uint16 => uint)[] nTickets; // deletable mapping

    constructor() {
        round = Round(block.timestamp + PHASE_LENGTH, 0);
        nTickets.push();
        isPurchased.push();
    }

    modifier phase(Phase p) {
        if (p == Phase.Sell) {
            require(block.timestamp < round.sellPhaseLimit, "sell phase ended");
        } else if (p == Phase.Draw) {
            require(
                block.timestamp >= round.sellPhaseLimit,
                "sell phase not ended"
            );
        } else if (p == Phase.Claim) {
            require(winningNumber != 0, "already drawn");
        }
        _;
    }

    // ===============| ILottery |================

    // 1. a user buys a ticket with a guess for this round
    // 2. ticket costs TICKET_PRICE: user should send exactly TICKET_PRICE
    // 3. no duplicate guess:uint16 allowed per user
    // 4. no limit on the number of tickets a user can buy
    function buy(uint16 guess) external payable override phase(Phase.Sell) {
        require(msg.value == TICKET_PRICE, "invalid ticket price");
        require(!isPurchased[0][msg.sender][guess], "already purchased");
        tickets.push(Ticket(msg.sender, guess));
        ++nTickets[0][guess];
        isPurchased[0][msg.sender][guess] = true;
    }

    // 0. assume service maintainer calls this function
    // 1. draw will determine the winning number for this round
    // 2. winning number range is [1, 65535]
    // 3. create a new round with a new sell phase limit
    // 4. determine the number of winners
    function draw() external override phase(Phase.Draw) {
        round.winningNumber = _generateWinningNumber();
        uint nWinners = nTickets[0][round.winningNumber];
        uint prize = nWinners > 0 ? address(this).balance / nWinners : 0;

        while (tickets.length > 0) {
            Ticket storage _ticket = tickets[tickets.length - 1];
            if (_ticket.guess == round.winningNumber) {
                rewards[_ticket.owner] += prize;
            }
            tickets.pop();
        }
        winningNumber = round.winningNumber;
        _initialize();
    }

    // 테스트에 명시된 claim phase에 대한 제한은 불필요하다.
    // 유저들이 언제나 claim 할 수 있도록 지원하는 것이 바람직하다 생각하고,
    // 본 컨트랙트의 구조를 활용하면 그것이 가능하다.
    // 다만, 테스트 통과를 위해 임시로 winningNumber를 중복 선언했다.
    function claim() external override phase(Phase.Claim) {
        uint reward = rewards[msg.sender];
        if (reward == 0) return;
        rewards[msg.sender] = 0;
        (bool res, ) = msg.sender.call{value: reward}("");
        require(res, "transfer failed");
    }

    // ================== Internal ==================

    function _generateWinningNumber() internal view returns (uint16) {
        return uint16((uint256(block.timestamp) % 65535) + 1);
    }

    function _initialize() internal {
        round.sellPhaseLimit = block.timestamp + PHASE_LENGTH;
        round.winningNumber = 0;
        nTickets.pop();
        nTickets.push();
        isPurchased.pop();
        isPurchased.push();
    }
}
