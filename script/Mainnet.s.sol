// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {DeadManSwitch} from "../src/DeadManSwitch.sol";

/// @notice Production deploy for Base mainnet (chainId 8453).
///         Stricter minInterval (1 hour) prevents foot-guns;
///         maxInterval (10 years) allows real inheritance setups.
contract Mainnet is Script {
    function run() external {
        uint256 pk = vm.envUint("THRYXTREASURY_PRIVATE_KEY");
        address treasury = vm.addr(pk);

        // Production parameters
        uint16 registerFeeBps = 50;            // 0.5%
        uint16 triggerBountyBps = 50;          // 0.5%
        uint16 maxRegisterFeeBps = 500;        // 5% hard cap (immutable)
        uint16 maxTriggerBountyBps = 500;      // 5% hard cap (immutable)
        uint64 minInterval = 1 hours;          // production floor
        uint64 maxInterval = 3650 days;        // ~10 years

        console2.log("Deployer / treasury:", treasury);
        console2.log("Chain ID:", block.chainid);

        // Hard guard: this script is for Base mainnet only
        require(block.chainid == 8453, "Mainnet.s.sol is for Base mainnet (chainId 8453) only");

        vm.startBroadcast(pk);
        DeadManSwitch dms = new DeadManSwitch(
            treasury,
            registerFeeBps,
            triggerBountyBps,
            maxRegisterFeeBps,
            maxTriggerBountyBps,
            minInterval,
            maxInterval
        );
        vm.stopBroadcast();

        console2.log("DeadManSwitch (mainnet) deployed at:", address(dms));
    }
}
