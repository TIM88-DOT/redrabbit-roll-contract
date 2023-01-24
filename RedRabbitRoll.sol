// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@chainlink/contracts/src/v0.8/VRFV2WrapperConsumerBase.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RedRabbitLottery is VRFV2WrapperConsumerBase, Ownable {
    event RollRequest(
        uint256 requestId,
        address indexed player,
        uint256 amount
    );

    event RollResult(
        uint256 requestId,
        address indexed player,
        bool won,
        uint256 amount
    );

    struct RollStatus {
        uint256 fees;
        uint256 amount;
        address player;
    }
    mapping(uint256 => RollStatus) public statuses;

    IERC20 public immutable redRabbitToken;

    address constant linkAddress = 0x326C977E6efc84E512bB9C30f76E30c160eD06FB;
    address constant vrfWrapperAddress =
        0x99aFAf084eBA697E584501b8Ed2c0B37Dd136693;

    uint32 constant callbackGasLimit = 100_000;
    uint32 constant numWords = 1;
    uint16 constant requestConfirmations = 3;

    constructor(IERC20 _redRabbitToken)
        payable
        VRFV2WrapperConsumerBase(linkAddress, vrfWrapperAddress)
    {
        redRabbitToken = IERC20(_redRabbitToken);
    }

    function roll(uint256 _amount) public {
        require(
            _amount < (redRabbitToken.balanceOf(address(this)) / 10) / 2,
            "Can't bet more than 5 % of the pool"
        );

        require(
            _amount > 10000000000000000000,
            "Can't bet less than 100 tokens"
        );

        redRabbitToken.transferFrom(msg.sender, address(this), _amount);

        uint256 requestId = requestRandomness(
            callbackGasLimit,
            requestConfirmations,
            numWords
        );

        delete statuses[requestId];

        emit RollRequest(requestId, msg.sender, _amount);
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        require(statuses[_requestId].fees > 0, "Request not found");

        RollStatus memory currentStatus = statuses[_requestId];

        if (_randomWords[0] % 2 == 0) {
            redRabbitToken.transfer(
                currentStatus.player,
                currentStatus.amount * 2
            );
            emit RollResult(
                _requestId,
                msg.sender,
                true,
                currentStatus.amount * 2
            );
        } else {
            emit RollResult(_requestId, msg.sender, false, 0);
        }
    }

    function getStatusByRequestId(uint256 _requestId)
        public
        view
        returns (RollStatus memory)
    {
        return statuses[_requestId];
    }

    function emeregencyWithdraw() external onlyOwner {
        redRabbitToken.transfer(
            msg.sender,
            redRabbitToken.balanceOf(address(this))
        );
    }
}
