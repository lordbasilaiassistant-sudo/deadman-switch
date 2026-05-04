// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {DeadManSwitch} from "../src/DeadManSwitch.sol";

contract Deploy is Script {
    function run() external {
        uint256 pk = vm.envUint("THRYXTREASURY_PRIVATE_KEY");
        address treasury = vm.addr(pk);

        // Sepolia config: relaxed bounds for testing
        // Mainnet config (separate deploy) would use stricter minInterval (1 days)
        uint16 registerFeeBps = 50;            // 0.5%
        uint16 triggerBountyBps = 50;          // 0.5%
        uint16 maxRegisterFeeBps = 500;        // 5% hard cap
        uint16 maxTriggerBountyBps = 500;      // 5% hard cap
        uint64 minInterval = 60;               // 60 seconds (Sepolia testing)
        uint64 maxInterval = 3650 days;        // 10 years

        console2.log("Deployer / treasury:", treasury);
        console2.log("Chain ID:", block.chainid);

        // Safety: 60-second minInterval is a testing config, not production.
        // Refuse to deploy to mainnets with these bounds.
        require(block.chainid == 84532 || block.chainid == 31337, "use Mainnet.s.sol for non-Sepolia deploys");

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

        console2.log("DeadManSwitch deployed at:", address(dms));
    }
}
