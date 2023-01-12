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

    address internal governance;
    address internal alice;

    function setUp() public virtual {
        utils = new Utils();
        users = utils.createUsers(2);
        governance = vm.addr(0x1);
        bridgeContract = new Bridge(3, 5, governance);
        token = new HLtoken("HackLodge", "HL");
        alice = vm.addr(0x2);
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
        rToken.approve(address(bridgeContract), transferAmount);
        bridgeContract.BridgeOut(_erc20Contract, transferAmount);
        assertEq(rToken.balanceOf(from), 0);
        assertEq(token.balanceOf(from), mintAmount - transferAmount);
        assertEq(token.balanceOf(address(bridgeContract)), transferAmount);
        assertEq(
            bridgeContract.getwithdrawAmt(from, _erc20Contract),
            transferAmount
        );
        vm.roll(6);
        bridgeContract.preWithdrawERC20(_erc20Contract);
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

contract WhenFreezeDuringBridgeOut is WhenBridgingIn {
    uint256 internal mintAmount = maxTransferAmount;
    bytes32 claimId;

    function setUp() public override {
        WhenBridgingIn.setUp();
        console.log("When Alice will bridge out funds, but tx got frozen");
        token.mint(alice, mintAmount);
    }

    function Freeze(
        address from,
        address _erc20Contract,
        uint256 transferAmount
    ) public {
        BridgeInToken(from, _erc20Contract, transferAmount);
        wERC20R rToken = wERC20R(bridgeContract.getRev(_erc20Contract));
        rToken.approve(address(bridgeContract), transferAmount);
        bridgeContract.BridgeOut(_erc20Contract, transferAmount);
        vm.stopPrank();
        vm.startPrank(governance);
        claimId = rToken.freeze(block.number / 1000, from, 0);
    }

    function itCantWithdrawOnceFreeze(
        address from,
        address _erc20Contract,
        uint256 transferAmount
    ) public {
        Freeze(from, _erc20Contract, transferAmount);
        wERC20R rToken = wERC20R(bridgeContract.getRev(_erc20Contract));
        assertEq(rToken.balanceOf(address(bridgeContract)), transferAmount);
        vm.roll(6);
        vm.stopPrank();
        vm.startPrank(alice);
        bridgeContract.preWithdrawERC20(_erc20Contract);
        vm.expectRevert(
            abi.encodePacked(
                "withdraw amt exceeded (take account of frozen asset)"
            )
        );
        bridgeContract.withdrawERC20(_erc20Contract, transferAmount);
    }

    function testCantWithdrawOnceFreeze(uint64 transferAmount) public {
        vm.assume(transferAmount != 0);
        itCantWithdrawOnceFreeze(
            alice,
            address(token),
            transferAmount % maxTransferAmount
        );
    }

    function itRevertOnceFreeze(
        address from,
        address _erc20Contract,
        uint256 transferAmount
    ) public {
        Freeze(from, _erc20Contract, transferAmount);
        vm.roll(2);
        assertEq(
            bridgeContract.getwithdrawAmt(from, _erc20Contract),
            transferAmount
        );
        wERC20R rToken = wERC20R(bridgeContract.getRev(_erc20Contract));
        assertEq(rToken.balanceOf(address(bridgeContract)), transferAmount);
        rToken.reverse(claimId);
        vm.roll(6);
        assertEq(rToken.balanceOf(address(bridgeContract)), 0);
        assertEq(
            bridgeContract.getwithdrawAmt(from, _erc20Contract),
            transferAmount
        );
        vm.stopPrank();
        vm.startPrank(alice);
        assertEq(
            bridgeContract.getwithdrawAmt(from, _erc20Contract),
            transferAmount
        );
        bridgeContract.preWithdrawERC20(_erc20Contract);
        assertEq(bridgeContract.getwithdrawAmt(from, _erc20Contract), 0);
        vm.expectRevert(
            abi.encodePacked(
                "withdraw amt exceeded (take account of frozen asset)"
            )
        );
        bridgeContract.withdrawERC20(_erc20Contract, transferAmount);
        assertEq(token.balanceOf(alice), mintAmount - transferAmount);
    }

    function testRevertOnceFreeze(uint64 transferAmount) public {
        vm.assume(transferAmount != 0);
        itRevertOnceFreeze(
            alice,
            address(token),
            transferAmount % maxTransferAmount
        );
    }

    function itRejRevertOnceFreeze(
        address from,
        address _erc20Contract,
        uint256 transferAmount
    ) public {
        Freeze(from, _erc20Contract, transferAmount);
        vm.roll(2);
        wERC20R rToken = wERC20R(bridgeContract.getRev(_erc20Contract));
        rToken.rejectReverse(claimId);
        vm.roll(6);
        vm.stopPrank();
        vm.startPrank(alice);
        assertEq(
            bridgeContract.getwithdrawAmt(from, _erc20Contract),
            transferAmount
        );
        assertEq(rToken.balanceOf(address(bridgeContract)), transferAmount);
        bridgeContract.withdrawERC20(_erc20Contract, transferAmount);
        assertEq(bridgeContract.getwithdrawAmt(from, _erc20Contract), 0);
        assertEq(rToken.balanceOf(address(bridgeContract)), 0);
        assertEq(token.balanceOf(alice), mintAmount);
    }

    function testRejRevertOnceFreeze(uint64 transferAmount) public {
        vm.assume(transferAmount != 0);
        itRejRevertOnceFreeze(
            alice,
            address(token),
            transferAmount % maxTransferAmount
        );
    }
}
