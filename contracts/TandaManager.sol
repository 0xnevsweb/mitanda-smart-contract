// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Tanda.sol";

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract TandaManager is VRFConsumerBaseV2Plus {
    uint256 private subscriptionId;
    bytes32 private gasLane;
    uint32 private callbackGasLimit;
    uint16 private requestConfirmations = 3;
    uint32 private numWords = 1;
    bool private nativePayment = true;

    address public immutable usdcAddress;
    uint256 public nextTandaId;
    uint16 public maxParticipants = 30;
    uint16 public creatorFee = 300;
    uint16 public treasuryFee = 200;
    address public treasuryWallet;

    mapping(uint256 => address) public tandaIdToAddress;
    mapping(uint256 => uint256) public vrfRequestIdToTandaId;
    mapping(uint256 => bool) public activeTandas;

    event TandaCreated(
        uint256 indexed tandaId,
        address indexed tandaAddress,
        uint256 contributionAmount,
        uint256 payoutInterval,
        uint16 participantCount,
        address creator
    );
    event RandomnessRequested(
        uint256 indexed tandaId,
        uint256 indexed requestId
    );
    event PayoutOrderAssigned(uint256 indexed tandaId);
    event VRFConfigUpdated(
        uint256 newSubscriptionId,
        bytes32 newGasLane,
        uint32 newCallbackGasLimit,
        uint16 newRequestConfirmations,
        uint32 newNumWords,
        bool newNativePayment
    );
    event FeeSettingsUpdated(
        uint16 creatorFee,
        uint16 treasuryFee,
        address treasuryWallet
    );
    event MaxParticipantsUpdated(uint16 newMaxParticipants);

    constructor(
        address _vrfCoordinator,
        uint256 _subscriptionId,
        bytes32 _gasLane,
        uint32 _callbackGasLimit,
        address _usdcAddress,
        address _treasuryWallet
    ) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        require(_vrfCoordinator != address(0), "Invalid VRF coordinator");
        require(_usdcAddress != address(0), "Invalid USDC address");
        require(_treasuryWallet != address(0), "Invalid treasury wallet");

        subscriptionId = _subscriptionId;
        gasLane = _gasLane;
        callbackGasLimit = _callbackGasLimit;
        usdcAddress = _usdcAddress;
        treasuryWallet = _treasuryWallet;
    }

    /**
     * @notice Update VRF configuration parameters
     */
    function updateVRFConfig(
        uint256 _subscriptionId,
        bytes32 _gasLane,
        uint32 _callbackGasLimit,
        uint16 _requestConfirmations,
        uint32 _numWords,
        bool _nativePayment
    ) external onlyOwner {
        subscriptionId = _subscriptionId;
        gasLane = _gasLane;
        callbackGasLimit = _callbackGasLimit;
        requestConfirmations = _requestConfirmations;
        numWords = _numWords;
        nativePayment = _nativePayment;

        emit VRFConfigUpdated(
            _subscriptionId,
            _gasLane,
            _callbackGasLimit,
            _requestConfirmations,
            _numWords,
            _nativePayment
        );
    }

    /**
     * @notice Update fee settings
     * @param _creatorFee New creator fee in basis points (max 400 = 4%)
     * @param _treasuryFee New treasury fee in basis points (max 400 = 4%)
     * @param _treasuryWallet New treasury wallet address
     */
    function updateFeeSettings(
        uint16 _creatorFee,
        uint16 _treasuryFee,
        address _treasuryWallet
    ) external onlyOwner {
        require(_creatorFee <= 400, "Creator fee cannot exceed 4%");
        require(_treasuryFee <= 400, "Treasury fee cannot exceed 4%");
        require(_treasuryWallet != address(0), "Invalid treasury wallet");
        require(
            _creatorFee + _treasuryFee <= 500,
            "Total fees cannot exceed 4%"
        );

        creatorFee = _creatorFee;
        treasuryFee = _treasuryFee;
        treasuryWallet = _treasuryWallet;

        emit FeeSettingsUpdated(_creatorFee, _treasuryFee, _treasuryWallet);
    }

    /**
     * @notice Update maximum number of participants per tanda
     * @param _maxParticipants New maximum participants (must be >= 2)
     */
    function updateMaxParticipants(uint16 _maxParticipants) external onlyOwner {
        require(_maxParticipants >= 2, "Minimum 2 participants");
        maxParticipants = _maxParticipants;
        emit MaxParticipantsUpdated(_maxParticipants);
    }

    /**
     * @notice Create a new Tanda
     * @param _contributionAmount USDC amount each participant must contribute
     * @param _payoutInterval Time between payouts in seconds
     * @param _participantCount Number of participants needed
     * @param _whitelist Array of whitelisted participant addresses
     * @return tandaId ID of the newly created Tanda
     */
    function createTanda(
        uint256 _contributionAmount,
        uint256 _payoutInterval,
        uint16 _participantCount,
        address[] calldata _whitelist
    ) external returns (uint256) {
        require(
            _contributionAmount >= 10 * 10 ** 6,
            "Minimum contribution 10 USDC"
        );
        require(_payoutInterval >= 1 days, "Minimum interval 1 day");
        require(_payoutInterval <= 30 days, "Maximum interval 30 days");
        require(_participantCount >= 2, "Minimum 2 participants");
        require(
            _participantCount <= maxParticipants,
            "Exceeds max participants"
        );
        require(
            _whitelist.length == _participantCount,
            "Whitelist length mismatch"
        );

        uint256 tandaId = nextTandaId++;
        Tanda tanda = new Tanda(
            tandaId,
            _contributionAmount,
            _payoutInterval,
            _participantCount,
            address(this),
            msg.sender,
            _whitelist
        );

        tandaIdToAddress[tandaId] = address(tanda);
        activeTandas[tandaId] = true;

        emit TandaCreated(
            tandaId,
            address(tanda),
            _contributionAmount,
            _payoutInterval,
            _participantCount,
            msg.sender
        );
        return tandaId;
    }

    /**
     * @notice Request randomness for payout order assignment
     * @dev Only callable by Tanda contracts
     */
    function requestRandomnessForTanda(uint256 tandaId) external {
        require(tandaIdToAddress[tandaId] == msg.sender, "Caller is not Tanda");
        require(activeTandas[tandaId], "Tanda is not active");

        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: gasLane,
                subId: subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: nativePayment})
                )
            })
        );

        vrfRequestIdToTandaId[requestId] = tandaId;

        emit RandomnessRequested(tandaId, requestId);
    }

    /**
     * @notice Callback function used by VRF Coordinator
     */
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        uint256 tandaId = vrfRequestIdToTandaId[requestId];
        require(tandaIdToAddress[tandaId] != address(0), "Invalid Tanda ID");

        Tanda tanda = Tanda(tandaIdToAddress[tandaId]);
        tanda.assignPayoutOrder(randomWords[0]);

        emit PayoutOrderAssigned(tandaId);
    }

    // ==================== View Functions ====================

    function getUsdcAddress() external view returns (address) {
        return usdcAddress;
    }

    function isTandaActive(uint256 tandaId) external view returns (bool) {
        return activeTandas[tandaId];
    }

    function getTandaAddress(uint256 tandaId) external view returns (address) {
        return tandaIdToAddress[tandaId];
    }

    function getActiveTandaIds() external view returns (uint256[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < nextTandaId; i++) {
            if (activeTandas[i]) {
                count++;
            }
        }

        uint256[] memory activeIds = new uint256[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < nextTandaId; i++) {
            if (activeTandas[i]) {
                activeIds[index] = i;
                index++;
            }
        }
        return activeIds;
    }

    function getFeeSettings() external view returns (uint16, uint16, address) {
        return (creatorFee, treasuryFee, treasuryWallet);
    }

    function getMaxParticipants() external view returns (uint16) {
        return maxParticipants;
    }

    function getVRFConfig()
        external
        view
        returns (uint256, bytes32, uint32, uint16, uint32, bool)
    {
        return (
            subscriptionId,
            gasLane,
            callbackGasLimit,
            requestConfirmations,
            numWords,
            nativePayment
        );
    }
}
