// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console} from "forge-std/console.sol";
import {stdStorage, StdStorage, Test} from "forge-std/Test.sol";

import {Utils} from "./utils/Utils.sol";
import "../src/Bridge.sol";
import "../src/HLtoken.sol";
import "../src/wERC20R.sol";

// To be continued
contract BaseSetup is Test {
    Bridge bridgeContract;
    HLtoken token;
    Utils internal utils;
    address payable[] internal users;

    address internal alice;
    address internal bob;

    function setUp() public virtual {
        utils = new Utils();
        users = utils.createUsers(2);
        bridgeContract = new Bridge();
        token = new HLtoken("HackLodge", "HL");
        alice = vm.addr(0x1);
    }
}

contract WhenBridgingIn is BaseSetup {
    uint256 internal maxTransferAmount = 12e18;

    function setUp() public virtual override {
        BaseSetup.setUp();
        console.log("When bridging token in");
    }

    function BridgeInToken(
        address from,
        address _erc20Contract,
        uint256 transferAmount
    ) public {
        vm.startPrank(from);
        token.approve(address(bridgeContract), transferAmount);
        bridgeContract.BridgeIn(_erc20Contract, transferAmount);
    }
}

contract WhenAliceHasSufficientFunds is WhenBridgingIn {
    uint256 internal mintAmount = maxTransferAmount;

    function setUp() public override {
        WhenBridgingIn.setUp();
        console.log("When Alice has sufficient funds");
        token.mint(alice, mintAmount);
    }

    function testMintCorrectly() public {
        assertEq(token.totalSupply(), token.balanceOf(alice));
    }

    function itBridgingInCorrectly(
        address from,
        address _erc20Contract,
        uint256 transferAmount
    ) public {
        uint256 fromBalanceBefore = token.balanceOf(from);
        BridgeInToken(from, _erc20Contract, transferAmount);

        assertEq(token.balanceOf(from), fromBalanceBefore - transferAmount);
        wERC20R rToken = wERC20R(bridgeContract.getRev(_erc20Contract));
        assertEq(rToken.balanceOf(from), transferAmount);
    }

    function testBridgingInWithFuzzing(uint64 transferAmount) public {
        vm.assume(transferAmount != 0);
        itBridgingInCorrectly(
            alice,
            address(token),
            transferAmount % maxTransferAmount
        );
    }
}

contract WhenAliceHasInsufficientFunds is WhenBridgingIn {
    uint256 internal mintAmount = maxTransferAmount - 1e18;

    function setUp() public override {
        WhenBridgingIn.setUp();
        console.log("When Alice has insufficient funds");
        token.mint(alice, mintAmount);
    }

    function itRevertsBridgingIn(
        address from,
        address _erc20Contract,
        uint256 transferAmount,
        string memory expectedRevertMessage
    ) public {
        vm.startPrank(from);
        HLtoken(_erc20Contract).approve(
            address(bridgeContract),
            transferAmount
        );
        vm.expectRevert(abi.encodePacked(expectedRevertMessage));
        bridgeContract.BridgeIn(_erc20Contract, transferAmount);
    }

    function testCannotBridgeMoreThanAvailable() public {
        itRevertsBridgingIn({
            from: alice,
            _erc20Contract: address(token),
            transferAmount: maxTransferAmount,
            expectedRevertMessage: "ERC20: transfer amount exceeds balance"
        });
    }
}

contract WhenAliceBridgeOut is WhenBridgingIn {
    uint256 internal mintAmount = maxTransferAmount;

    function setUp() public override {
        WhenBridgingIn.setUp();
        console.log("When Alice will bridge out funds");
        token.mint(alice, mintAmount);
    }

    function itBridgingOutCorrectly(
        address from,
        address _erc20Contract,
        uint256 transferAmount
    ) public {
        assertEq(token.balanceOf(alice), mintAmount);
        BridgeInToken(from, _erc20Contract, transferAmount);
        wERC20R rToken = wERC20R(bridgeContract.getRev(_erc20Contract));
        assertEq(rToken.balanceOf(from), transferAmount);
        bridgeContract.BridgeOut(_erc20Contract, transferAmount);
        assertEq(rToken.balanceOf(from), 0);
        assertEq(token.balanceOf(from), mintAmount - transferAmount);
        assertEq(token.balanceOf(address(bridgeContract)), transferAmount);
        assertEq(
            bridgeContract.getwithdrawAmt(from, _erc20Contract),
            transferAmount
        );
        vm.roll(6);
        bridgeContract.withdrawERC20(_erc20Contract, transferAmount);
        assertEq(bridgeContract.getwithdrawAmt(from, _erc20Contract), 0);
        assertEq(token.balanceOf(alice), mintAmount);
    }

    function testBridgingOutWithFuzzing(uint64 transferAmount) public {
        vm.assume(transferAmount != 0);
        itBridgingOutCorrectly(
            alice,
            address(token),
            transferAmount % maxTransferAmount
        );
    }
}
