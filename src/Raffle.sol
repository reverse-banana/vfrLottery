// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title Raffle
 * @author Joy Barricks
 * @notice Contract for creating simple raffle
 * @dev Implements Chainlink VRFv2.5
 */
contract Raffle is VRFConsumerBaseV2Plus {
    // Type declaration
    enum RaffleState {
        OPEN,
        CALCULATING
    }
    // calculating status is restiriting palyers to enter due to the block confirmation value 
    // specified for picking the winner 

    // Errors
    error Raffle__SendMoreToEnterTheRaffle();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle_UpkeepNotNeeded(uint256 balance, uint256 playersLength, uint256 raffleState);

    /**
     * Const var for the VFRclient
     */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    // Current contract vars
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    // Custom struct object vars for the VFRCLient
    bytes32 private immutable i_gasLane;
    uint32 private immutable i_callbackGasLimit;
    uint256 private immutable i_subscriptionId;

    //** Events */

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    // Constructor
    constructor(
        uint256 entranceFee,
        uint256 interval,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit,
        address vrfCoordinator
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_gasLane = gasLane;
        i_interval = interval;
        i_subscriptionId = subscriptionId;
        i_entranceFee = entranceFee;
        i_callbackGasLimit = callbackGasLimit;
        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
        // we make the by RaffleState(0)
    }

    // Functions
    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreToEnterTheRaffle();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
        // every time you update storage you would want to emit event for it
    }

    // @dev chainlink keeper function that monitors if the next round should started based on the bool true value
    // @param - ingnored
    // @return - ignored
    function checkUpKeep(bytes memory /* checkData */) 
    public 
    view
    returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) >= i_interval);
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
        // declaring that upkeepNeeded can be evaluated to true only after all bools in are also true
        return (upkeepNeeded, "");
        // returning the upkeepneeded and the black bytes memory arg
    }

    function performUpkeep(bytes calldata /* performData*/) external {
        (bool upkeepNeeed, ) = checkUpKeep("");
        if (!upkeepNeeed){
            revert Raffle_UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }        

        s_raffleState = RaffleState.CALCULATING;

        // init of RandomWodsRequesr struct from the VRF2PlusClient contract
        // that will basically send the request for random words to the chainlink node
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient
            .RandomWordsRequest({
                keyHash: i_gasLane,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            });
        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
        emit RequestedRaffleWinner(requestId);
    }

    // defining set of commands what to do when we will get the random words from the node (unknown format for now)
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        // randoWords  retuns as the array with element amount of NUM_WORDS
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        // resseting array
        s_lastTimeStamp = block.timestamp;
        // resetting time stamp value
        
        emit WinnerPicked(s_recentWinner);
        // it's good practice to emot before external interactions
        
        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    /**
     * Getter Functions
     */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }


    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayers(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }


}
