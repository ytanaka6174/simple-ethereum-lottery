//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/Script.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "script/Interactions.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {Vm} from "forge-std/Vm.sol";
import {Raffle} from "src/Raffle.sol";

contract InteractionsTest is Test {
    Raffle public raffle;
    HelperConfig public helperConfig;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();
    }

    // CreateSubscription Tests
    function testSubscriptionIdIsNonZero() public {
        //Arrange
        CreateSubscription createSubscription = new CreateSubscription();
        //Act
        (uint256 subid,) = createSubscription.createSubscriptionUsingConfig();
        //Assert
        assert(subid != 0);
    }

    function testSubscriptionIsActuallyRegistered() public {
        // Arrange
        CreateSubscription createSubscription = new CreateSubscription();
        // Act
        (uint256 subId, address vrfCoordinator) = createSubscription.createSubscriptionUsingConfig();
        // Assert - Query the VRF coordinator to verify the subscription exists
        VRFCoordinatorV2_5Mock vrfMock = VRFCoordinatorV2_5Mock(vrfCoordinator);
        // Get subscription details - if subscription doesn't exist, this will revert
        (uint96 balance,,, address subOwner,) = vrfMock.getSubscription(subId);
        // Verify subscription has an owner (proves it was created)
        assert(subOwner != address(0));
        // Verify subscription ID is greater than 0
        assert(subId > 0);
        // Initial balance should be 0 (not funded yet)
        assertEq(balance, 0);
        console.log("Subscription ID:", subId);
        console.log("Subscription Owner:", subOwner);
    }

    //FundSubscription Tests
    function testSubscriptionBalanceIncreasesWithFunding() external {
        //Arrange
        CreateSubscription createSubscription = new CreateSubscription();
        (uint256 subId, address vrfCoordinator) = createSubscription.createSubscriptionUsingConfig();
        VRFCoordinatorV2_5Mock vrfMock = VRFCoordinatorV2_5Mock(vrfCoordinator);
        //HelperConfig helperConfig = new HelperConfig();
        address link = helperConfig.getConfig().link;
        (uint96 prevBalance,,,,) = vrfMock.getSubscription(subId);
        uint256 beforeFundingBalance = prevBalance;
        //Act
        FundSubscription fundSubscription = new FundSubscription();
        fundSubscription.fundSubscription(vrfCoordinator, subId, link);
        (uint96 newBalance,,,,) = vrfMock.getSubscription(subId);
        uint256 afterFundingBalance = newBalance;
        console.log("Prev Balance: ", prevBalance);
        console.log("New Balance: ", newBalance);
        //Assert
        assert(prevBalance < newBalance);
    }

    //Add Consumer Tests
    function testAddConsumerEventEmits() external {
        //Arrange
        CreateSubscription createSubscription = new CreateSubscription();
        (uint256 subId, address vrfCoordinator) = createSubscription.createSubscriptionUsingConfig();
        AddConsumer addConsumer = new AddConsumer();
        vm.recordLogs();
        addConsumer.addConsumer(address(raffle), vrfCoordinator, subId);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        // The consumer address is NOT indexed, so it's in the data field, not topics
        // We need to decode the data field to get the address
        address consumerAddress = abi.decode(entries[0].data, (address));
        assertEq(consumerAddress, address(raffle));
    }
}
