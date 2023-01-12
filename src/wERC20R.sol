// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.0;
import "./ERC20R.sol";

contract wERC20R is ERC20R {
    address private bridgeContract;

    // IERC20 public immutable underlying;
    constructor(
        string memory name,
        string memory symbol,
        uint256 numReversibleBlocks,
        address governanceContract
    ) ERC20R(name, symbol, numReversibleBlocks, governanceContract) {
        bridgeContract = msg.sender;
    }

    // modifier onlyBridge() {
    //     require(
    //         bridgeContract == msg.sender,
    //         "wERC20R: only the bridge can trigger this method!"
    //     );
    //     _;
    // }

    function mint(address account, uint256 amount) public virtual onlyBridge {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) public virtual onlyBridge {
        _burn(account, amount);
    }
}
