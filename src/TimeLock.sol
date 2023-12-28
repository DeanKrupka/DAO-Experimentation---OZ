//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract TimeLock is TimelockController {
    // minDelay is the minimum time between queueing a transaction and execution
    // proposers is the list of addresses that can call `propose()`
    // executors is the list of addresses that can call `execute()`
    constructor(uint256 minDelay, address[] memory proposers, address[] memory executors)
        TimelockController(minDelay, proposers, executors, msg.sender)
    {}
}
