// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IRandomizoor {
    function randomGen() external returns (uint256);
}

contract RedRabbitLottery is Ownable {
    event RollRequest(address indexed player, uint256 amount);

    event RollResult(address indexed player, bool won, uint256 amount);

    IERC20 public immutable redRabbitToken;
    IRandomizoor public randomizer;

    uint16 taxPercentage = 2;
    uint16 maxPercentage = 5;

    uint256 minTokens = 200000 * 10**18;

    constructor(IERC20 _redRabbitToken, address _randomizer) {
        redRabbitToken = IERC20(_redRabbitToken);
        randomizer = IRandomizoor(_randomizer);
    }

    function roll(uint256 _amount) public {
        require(
            _amount <
                (redRabbitToken.balanceOf(address(this)) * maxPercentage) / 100,
            "Can't bet more than the max"
        );

        require(_amount >= minTokens, "Can't bet less than the minimum");

        require(tx.origin == msg.sender, "must not be another contract");

        uint256 taxedAmount = _amount - ((_amount * taxPercentage) / 100); // 2% of amount tax

        redRabbitToken.transferFrom(msg.sender, address(this), _amount);
        _roll(taxedAmount);
    }

    function _roll(uint256 _taxedAmount) internal {
        uint256 randomWord = randomizer.randomGen();
        if (randomWord % 2 == 0) {
            redRabbitToken.transfer(msg.sender, _taxedAmount * 2);
            emit RollResult(msg.sender, true, _taxedAmount * 2);
        } else {
            redRabbitToken.transfer(msg.sender, 1 * 10**18);
            emit RollResult(msg.sender, false, 0);
        }
    }

    function recoverToken(address _token) external onlyOwner {
        uint256 balance = IERC20(_token).balanceOf(address(this));
        require(balance != 0, "Cannot recover zero balance");

        IERC20(_token).transfer(address(msg.sender), balance);
    }

    function setTaxPercentage(uint16 _taxPercentage) public onlyOwner {
        require(_taxPercentage <= 10, "Can't set more than 10% tax");
        taxPercentage = _taxPercentage;
    }

    function setMaxPercentage(uint16 _maxPercentage) public onlyOwner {
        maxPercentage = _maxPercentage;
    }

    function setMinTokens(uint256 _minTokens) public onlyOwner {
        minTokens = _minTokens;
    }
}
