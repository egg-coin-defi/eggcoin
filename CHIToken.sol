// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title CHIToken
 * @dev ERC20 token representing surplus value in the EggCoin pool
 * Fluctuates based on total collateral
 * No owner, no admin – fully decentralized
 */
contract CHIToken is ERC20 {
    /**
     * @dev Initializes the contract with name "Chi Coin" and symbol "CHI"
     */
    constructor() ERC20("Chi Coin", "CHI") {}

    /**
     * @dev Mints new CHI tokens
     * Only callable by the EggChiVault contract
     * @param account The address to receive new tokens
     * @param amount The number of tokens to mint
     */
    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    /**
     * @dev Burns CHI tokens during redeem process
     * @param amount The number of tokens to burn
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}