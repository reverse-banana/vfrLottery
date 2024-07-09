// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";


abstract contract CodeConstant {
    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;

    // VRF mock values
    uint96 public MOCK_BASE_FEE = 0.25 ether;
    uint96 public MOCK_GAS_PRICE_LINK = 1e9;
    int256 public MOCK_WEI_PER_UINT_LINK = 4e15;
    }


contract HelperConfig is Script, CodeConstant {
    error HelperConfig__InvalidChainId();
    
    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        bytes32 gasLane;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
        address vrfCoordinator;
        address link;
    }


    NetworkConfig public localNetworkConfig;
    mapping (uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
        // assigning the data of the returned NetworkConfig to the key ETH_SEPOLIA_CHAIN_ID
    }

    function getConfigByChainId(uint256 chainId) public returns(NetworkConfig memory) {
        if(networkConfigs[chainId].vrfCoordinator != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getSepoliaEthConfig() public pure returns(NetworkConfig memory) {
        return NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30, // 30 seconds
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId:0,
            callbackGasLimit: 500000,// 500k gas
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789
        });
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }
    // enhance usubility function to get the config during the deploy by passing chain id

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }

        //deploying the mock
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorMock = new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK, MOCK_WEI_PER_UINT_LINK);
        // when using mock check it's constructor for the arg it's take

        LinkToken linkToken = new LinkToken();
        // seems that specifying the inherited contract constructor only for works for the level down contact
        // but not all the hierarchy of importthat makes sense cause we would 10-15 constructor during init
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30, // 30 seconds
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId:0,
            callbackGasLimit: 500000,// 500k gas
            vrfCoordinator: address(vrfCoordinatorMock),
            link: address(linkToken)
        });

        return localNetworkConfig;

    }
}

