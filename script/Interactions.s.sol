// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CodeConstant} from "./HelperConfig.s.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";



contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        // getting the active config for the network and filtering the propery that we want to fetch

        (uint256 subId,) = createSubscription(vrfCoordinator);

        return (subId, vrfCoordinator);
    }
    
    function createSubscription(address vfrCoordinator) public returns (uint256, address) {
        console.log("Creating subscription on chain Id: ", block.chainid);
        vm.startBroadcast();
        uint256 subId = VRFCoordinatorV2_5Mock(vfrCoordinator).createSubscription();
        vm.stopBroadcast();

        console.log("Your subscritpion Id is: ", subId);
        return (subId, vfrCoordinator);
    }


    function run() public {
        createSubscriptionUsingConfig();
    }
}


contract FundSubscription is Script, CodeConstant {
        uint256 public constant FUND_AMOUNT = 3 ether; // 3 LINK

        function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address linkToken = helperConfig.getConfig().link;
        fundSubscription(vrfCoordinator, subscriptionId, linkToken);
        }

        function fundSubscription(address vrfCoordinator, uint256 subscriptionId, address linkToken) public {
            console.log("Funding subscription: ", subscriptionId);
            console.log("Using vfrCoordinator ", vrfCoordinator);
            console.log("On ChainID: ", block.chainid);

            if (block.chainid == LOCAL_CHAIN_ID ) {
                vm.startBroadcast();
                VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, FUND_AMOUNT);
                vm.stopBroadcast();
            } else {
                vm.startBroadcast();
                LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subscriptionId));
                vm.stopBroadcast();
            }
        }
        
        
        function run() public {
        fundSubscriptionUsingConfig();
        }
}

contract AddConsumer is Script {
    function  addConsumerUsingConfig(address mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        uint256 subId =  helperConfig.getConfig().subscriptionId;
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        addComsumer(mostRecentlyDeployed, vrfCoordinator, subId);
    }


    function addComsumer(address contractToAddToVrf, address vfrCoordinator, uint256 subId) public {
        console.log("Adding contract to VRF Coordinator ", contractToAddToVrf);
        console.log("VFR Coordinator value ", vfrCoordinator);
        console.log("On chain-id ", block.chainid);
        console.log("With the subId of ", subId);
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock(vfrCoordinator).addConsumer(subId, contractToAddToVrf);
        vm.stopBroadcast();
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployed);
    }
}