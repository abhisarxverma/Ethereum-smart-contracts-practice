// SPDX-License-Identifier: MIT

pragma solidity ^0.8.34;

import {Script} from "forge-std/Script.sol";
import {MultiSigWallet} from "../src/MultiSigWallet.sol";

contract DeployMultiSigWallet is Script {
    function run(address[] memory owners, uint256 requiredApprovals) external returns (MultiSigWallet) {
        vm.startBroadcast();
        MultiSigWallet multiSigWallet = new MultiSigWallet(owners, requiredApprovals);
        vm.stopBroadcast();
        return multiSigWallet;
    }
}
