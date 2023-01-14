// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.0;
import "./wERC20R.sol";
import "openzeppelin-contracts/token/ERC20/ERC20.sol";

contract Bridge {
    uint256 private delayBlock;
    // map erc --> rev erc
    mapping(address => address) revTokenMap;

    function getRev(address _erc20Contract) public view returns (address) {
        return revTokenMap[_erc20Contract];
    }

    struct withdrawInfo {
        uint256 amt;
        uint256 startBlock;
    }
    //map wallet --> erc20 --> withdrawinfo
    mapping(address => mapping(address => withdrawInfo)) withdrawBalance;
    uint256 private numReversibleBlocks;
    address private governanceContract;

    function getwithdrawInfo(
        address from,
        address _erc20Contract
    ) public view returns (uint256, uint256) {
        return (withdrawBalance[from][_erc20Contract].amt, withdrawBalance[from][_erc20Contract].startBlock);
    }



    constructor(
        uint256 _numReversibleBlocks,
        uint256 _delayBlock,
        address _governanceContract
    ) {
        delayBlock = _delayBlock;
        numReversibleBlocks = _numReversibleBlocks;
        governanceContract = _governanceContract;
    }

    // deposit erc20 to get werc20R
    function BridgeIn(address _erc20Contract, uint256 amount) public {
        // Create a reference to the underlying asset contract, like DAI.
        ERC20 underlying = ERC20(_erc20Contract);

        // Create a reference to the corresponding rToken contract, like rDAI
        wERC20R rToken;
        if (revTokenMap[_erc20Contract] == address(0)) {
            rToken = new wERC20R(
                string(abi.encodePacked("Novo ", underlying.name())),
                string(abi.encodePacked("N-", underlying.symbol())),
                numReversibleBlocks,
                governanceContract,
                underlying.decimals()
            );
            revTokenMap[_erc20Contract] = address(rToken);
        } else {
            rToken = wERC20R(revTokenMap[_erc20Contract]);
        }
        underlying.transferFrom(msg.sender, address(this), amount);
        rToken.mint(msg.sender, amount);
    }

    // burn werc20R to get erc20
    function BridgeOut(address _erc20Contract, uint256 amount) public {
        require(revTokenMap[_erc20Contract] != address(0), "no such rToken");
        // Create a reference to the corresponding rToken contract, like rDAI
        wERC20R rToken = wERC20R(revTokenMap[_erc20Contract]);
        require(rToken.balanceOf(msg.sender) >= amount, "Not enough rtoken");
        rToken.transferFrom(msg.sender, address(this), amount);

        // burn(msg.sender, amount);

        if (withdrawBalance[msg.sender][_erc20Contract].amt == 0) {
            withdrawBalance[msg.sender][_erc20Contract].amt = amount;
        } else {
            withdrawBalance[msg.sender][_erc20Contract].amt += amount;
        }
        withdrawBalance[msg.sender][_erc20Contract].startBlock = block.number;
    }

    function preWithdrawERC20(address _erc20Contract) public {
        wERC20R rToken = wERC20R(revTokenMap[_erc20Contract]);
        if (rToken.getRevertAmount(msg.sender) > 0) {
            withdrawBalance[msg.sender][_erc20Contract].amt -= rToken
                .getRevertAmount(msg.sender);
            rToken.resetRevertAmount(msg.sender);
        }
    }

    function withdrawERC20(address _erc20Contract, uint256 amount) public {
        require(
            block.number >=
                withdrawBalance[msg.sender][_erc20Contract].startBlock +
                    delayBlock,
            "Time (Block) doesn't pass enough yet"
        );
        // check active bridge debt, if pass
        wERC20R rToken = wERC20R(revTokenMap[_erc20Contract]);

        require(
            withdrawBalance[msg.sender][_erc20Contract].amt -
                rToken.getActiveBridgeDebt(msg.sender) >=
                amount,
            "withdraw amt exceeded (take account of frozen asset)"
        );
        // burn rToken
        rToken.burn(address(this), amount);
        ERC20 underlying = ERC20(_erc20Contract);
        withdrawBalance[msg.sender][_erc20Contract].amt -= amount;
        underlying.transfer(msg.sender, amount);
    }
}
