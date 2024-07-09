// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";



contract RaffleTest is Test {
    Raffle public raffle;
    HelperConfig public helperConfig;

    // declaring the vars not to access them by as a property of the helperConfig object
    uint256 entranceFee;
    uint256 interval;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;
    address vrfCoordinator;

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    modifier raffleEntered() {
     vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1 );
    _;
    }

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();
        // saving returned object to the state variable 
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;
        vrfCoordinator = config.vrfCoordinator;
        // since the values in the vars that we run by script or by manual deploy are the vars of other instance
        // in out test we want to get the specific values and create an automatic deploy flow which we will be testing
        // the contract know about the vars by import but not the values itself that why we have to init a new a separate instance in new files
        // I still can't atriculate correctly what I have problem and how it's works, but I start to understand
    
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
        // here you refering to the contract type notthe variable itslef
        //assert(uint256(raffle.getRaffleState()) == 0);
        // addressing the enum states in the numeric formatl
    }


    function testRaffleRevertsWhenYouDontPayEnought() public {
        // arrange
        vm.prank(PLAYER);
        // act / assert 
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterTheRaffle.selector);
        // checking that revert throws the custom error that we specified in the contract logic on the next tnx
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        address playerRecorded = raffle.getPlayers(0);
        // assigning the value of the address that entered an array to the var for futher assert

        assert(playerRecorded == PLAYER);
    }

    function testEnteringRaffleEmitsEvent() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        // the address(raffle) is the address from who, we expect emit
        emit RaffleEntered(PLAYER);
        // what exaclty event that we expect to emit here and it's value we are expecting to have
        // fyi: in order to use events we have to copy paste directly to the file

        raffle.enterRaffle{value: entranceFee}();
        // firing the enterRaffle function which should emit the event if valid data is passed
        // no additional assertion needed for now 

    }

    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        
        vm.warp(block.timestamp + interval + 1);
        // adjusting  current block.timestamp value by adding interval emount and +1 to make sure it's always be bigger that needed
        vm.roll(block.number + 1);
        // also changing the block number for better simulation
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

    }

    // checkupkeepchecks

    function testCheckUpKeepReturnsFalseIfItHasNoBalance() public {
        // arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        
        (bool upkeepNeeded, ) = raffle.checkUpKeep("");

        // assert
        assert(!upkeepNeeded);
    }    

    function testCheckUpkeepReturnsFalseIfRaffleIsntOpen() public raffleEntered {

        raffle.performUpkeep("");


        (bool upkeepNeeded, ) = raffle.checkUpKeep("");
        assert(!upkeepNeeded);
    }

    // performUpkeep test

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public raffleEntered {

        raffle.performUpkeep("");
        // firing the performUpkeep which only works if upkeepNeeded is true
    }    


    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();
        // when we working with the custom erros what have params in it we should create them
        // during arrange phase of the test

        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle_UpkeepNotNeeded.selector, currentBalance, numPlayers, rState)
        );
        raffle.performUpkeep("");
        // checking custom reverts by passing the args of the custom error with the expect revert stament and than 
        // calling performUpkeep function to check it 
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public raffleEntered {
     
       vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        // we choose entries[1] cause in our code vfr interface emitting also before us same event
        // and we start looking from topics[1] cause dy default [0] index is reserved for somwthing else

        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        // typecating the bytes32 reuqestId into uint
        assert(uint(raffleState) == 1); 
    }

    // fullfillrandomwords

    function testFulfillrandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId) public raffleEntered {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));


    }

}