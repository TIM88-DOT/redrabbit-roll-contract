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
        uint256 randomWord;
        uint256 amount;
        address player;
        bool fulfilled;
    }
    mapping(uint256 => RollStatus) public statuses;

    IERC20 public immutable redRabbitToken;

    address constant linkAddress = 0x326C977E6efc84E512bB9C30f76E30c160eD06FB;
    address constant vrfWrapperAddress =
        0x99aFAf084eBA697E584501b8Ed2c0B37Dd136693;

    uint32 constant callbackGasLimit = 300_000;
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

        redRabbitToken.transferFrom(msg.sender, address(this), _amount);

        uint256 requestId = requestRandomness(
            callbackGasLimit,
            requestConfirmations,
            numWords
        );

        statuses[requestId] = RollStatus({
            fees: VRF_V2_WRAPPER.calculateRequestPrice(callbackGasLimit),
            randomWord: 0,
            amount: _amount,
            player: msg.sender,
            fulfilled: false
        });

        emit RollRequest(requestId, msg.sender, _amount);
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        require(statuses[_requestId].fees > 0, "Request not found");

        statuses[_requestId].fulfilled = true;
        statuses[_requestId].randomWord = _randomWords[0];

        RollStatus memory currentStatus = statuses[_requestId];

        if (_randomWords[0] % 2 == 0) {
            redRabbitToken.transfer(
                currentStatus.player,
                currentStatus.amount * 2
            );
            emit RollResult(
                _requestId,
                currentStatus.player,
                true,
                currentStatus.amount
            );
        } else {
            emit RollResult(_requestId, currentStatus.player, false, 0);
        }
    }

    function getStatusByRequestId(uint256 _requestId)
        public
        view
        returns (RollStatus memory)
    {
        return statuses[_requestId];
    }

    function recoverToken(address _token) external onlyOwner {
        uint256 balance = IERC20(_token).balanceOf(address(this));
        require(balance != 0, "Cannot recover zero balance");

        IERC20(_token).transfer(address(msg.sender), balance);
    }
}
