// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.0;
import "forge-std/Script.sol";
import "../src/Bridge.sol";
import "../src/Faucet.sol";
import "openzeppelin-contracts/token/ERC20/ERC20.sol";

contract MyScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        new Bridge(300, 300, 0x83874a4d8ceEB714632747AE00B954B0B71CBD0b);
    }
}

contract DeployFaucet is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        new Faucet(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    }
}

contract GetNTokenAddresses is Script {
    function run() external {

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        // TODO Replace
        address bridge = 0x01cf58e264d7578D4C67022c58A24CbC4C4a304E;
        Bridge bridgeContract = Bridge(bridge);

        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;


        ERC20 underlying = ERC20(usdc);
        underlying.approve(bridge, 100);

        bridgeContract.BridgeIn(usdc, 100);

        address rusdc = bridgeContract.getRev(usdc);
        console.log("RUSDC");
        console.logAddress(rusdc);
    }
}


// contract PrintUSDC is Script {
//     function run() external {

//         uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
//         vm.startBroadcast(deployerPrivateKey);
//         address bridge = 0x01cf58e264d7578D4C67022c58A24CbC4C4a304E;
//         Bridge bridgeContract = Bridge(bridge);

//         address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;


//         ERC20 underlying = ERC20(usdc);
//         underlying.approve(bridge, 100);

//         bridgeContract.BridgeIn(usdc, 100);

//         address rusdc = bridgeContract.getRev(usdc);
//         console.log("RUSDC");
//         console.logAddress(rusdc);
//     }
// }