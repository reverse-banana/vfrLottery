// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";


contract DeployRaffle is Script {
    function run() public {
        deployContract();
    }

    function deployContract() public returns(Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        if (config.subscriptionId == 0){
            CreateSubscription createSubscription = new CreateSubscription();
            
            (config.subscriptionId, config.vrfCoordinator) = createSubscription.createSubscription(config.vrfCoordinator);   
            // creating the new subscriptiong id with exisiting vfrCoodrinator from config
            // but we also have an option to add a new one as argument for the fucntion
            // since the createSub function returns the subId and vfrCoordinator value we save in the this reerse syntax
        
            // fund it

        FundSubscription fundSubscription = new FundSubscription();
        fundSubscription.fundSubscription(config.vrfCoordinator, config.subscriptionId, config.link);

        
        }


        vm.startBroadcast();
        Raffle raffle = new Raffle(
        config.entranceFee,
        config.interval,
        config.gasLane,
        config.subscriptionId,
        config.callbackGasLimit,
        config.vrfCoordinator
        );
        vm.stopBroadcast();


        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addComsumer(address(raffle), config.vrfCoordinator, config.subscriptionId);

        return (raffle, helperConfig);
        // the main idea is to deploy the contract and automate the process by using the value
        // that we get from the HelperConfig and pass them into the raffle constructor
        // which dynamicly changes based on what chain we currecly on
    }
}