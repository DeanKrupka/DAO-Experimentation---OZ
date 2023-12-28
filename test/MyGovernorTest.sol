//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {Box} from "../src/Box.sol";
import {TimeLock} from "../src/TimeLock.sol";
import {GovToken} from "../src/GovToken.sol";

contract MyGovernorTest is Test {
    MyGovernor governor;
    Box box;
    TimeLock timeLock;
    GovToken govToken;

    address public USER = makeAddr("user");
    uint256 public constant INITIAL_SUPPLY = 100 ether;

    address[] public proposers;
    address[] public executors;
    uint256[] public values;
    bytes[] public calldatas;
    address[] public targets;

    uint256 public constant MIN_DELAY = 3600; // 1 hour
    uint256 public constant VOTING_DELAY = 1; // Number of blocks till a vote is active
    uint256 public constant VOTING_PERIOD = 50400; // 1 week;

    function setUp() public {
        govToken = new GovToken();
        govToken.mint(USER, INITIAL_SUPPLY);

        vm.startPrank(USER);
        govToken.delegate(USER);
        timeLock = new TimeLock(MIN_DELAY, proposers, executors); //bc these proposer and executer arrays are blank, it means anyone can propose and execute
        governor = new MyGovernor(govToken, timeLock);

        //Grant a whole bunch of roles
        bytes32 proposerRole = timeLock.PROPOSER_ROLE(); // only Governor can propose to timelock
        bytes32 executorRole = timeLock.EXECUTOR_ROLE();
        bytes32 adminRole = timeLock.DEFAULT_ADMIN_ROLE();

        timeLock.grantRole(proposerRole, address(governor));
        timeLock.grantRole(executorRole, address(0)); // this is set to anybody bc 0 address (anyone can execute a past proposal)
        timeLock.revokeRole(adminRole, USER);
        vm.stopPrank();

        box = new Box();
        box.transferOwnership(address(timeLock)); // timelock owns the dao, and the dao owns the timelock. But the timelock to decide where and when shit goes,
    }

    function testCantUpdateBoxWithoutGovernance() public {
        vm.expectRevert();
        box.store(1);
    }

    function testGovUpdatesBox() public {
        uint256 valueToStore = 888;
        string memory description = "store 1 in Box";
        bytes memory encodedFunctionCall = abi.encodeWithSignature("store(uint256)", valueToStore);

        values.push(0);
        calldatas.push(encodedFunctionCall);
        targets.push(address(box));

        // now we can call propose function
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        //view state - Should be Pending (0)
        console.log("Proposal State:", uint256(governor.state(proposalId)));

        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);

        //view state - Should be Active (1)
        console.log("Proposal State:", uint256(governor.state(proposalId)));

        // Now because its active we can vote
        uint8 voteWay = 1; //1 = yes, 2 = no, 3 = abstain
        string memory reason = "Yep, I vote yes";
        vm.prank(USER);
        governor.castVoteWithReason(proposalId, voteWay, reason); // This is error

        //Speed up voting period
        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        console.log("Proposal State:", uint256(governor.state(proposalId)));

        // Queue the tx
        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        governor.queue(targets, values, calldatas, descriptionHash);

        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.roll(block.number + MIN_DELAY + 1);

        // Execute the tx
        governor.execute(targets, values, calldatas, descriptionHash);

        assert(box.getNumber() == valueToStore);
        console.log("Box number:", box.getNumber());
    }
}
