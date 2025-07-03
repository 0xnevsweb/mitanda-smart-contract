// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface VRFCoordinatorV2_5Interface {
    function requestRandomWords(
        bytes32 keyHash,
        uint256 subId,
        uint16 minimumRequestConfirmations,
        uint32 callbackGasLimit,
        uint32 numWords,
        bytes memory extraArgs
    ) external returns (uint256 requestId);
}