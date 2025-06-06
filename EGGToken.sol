// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title EGGToken
 * @dev ERC20 token for EggCoin Finance system
 * Stablecoin soft-pegged to $1.00 USD
 * No governance, no admin – only minting and burning via vault contract
 */
contract EGGToken is ERC20 {
    /**
     * @dev Initializes the contract with name "Egg Dollar" and symbol "EGG$"
     */
    constructor() ERC20("Egg Dollar", "EGG$") {}

    /**
     * @dev Mints new EGG$ tokens
     * Can only be called by the EggChiVault contract
     * @param account The address to receive new tokens
     * @param amount The number of tokens to mint
     */
    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    /**
     * @dev Burns EGG$ tokens when redeemed
     * @param amount The number of tokens to burn
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}