// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract Randomizoor {
    uint256 private nonce;
    
    function randomGen() external returns (uint256) {
        nonce++;
        return uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp +
                        block.difficulty +
                        ((
                            uint256(keccak256(abi.encodePacked(block.coinbase)))
                        ) / (block.timestamp)) +
                        block.gaslimit +
                        ((uint256(keccak256(abi.encodePacked(tx.origin)))) /
                            (block.timestamp)) +
                        block.number +
                        nonce
                )
            )
        );
    }

}
