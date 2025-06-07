// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title CHIToken
 * @dev Surplus token for EggCoin system, fully decentralized
 */
contract CHIToken is ERC20 {
    address public immutable vault;

    event Minted(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);

    modifier onlyVault() {
        require(msg.sender == vault, "CHIToken: caller is not the vault");
        _;
    }

    constructor(address _vault) ERC20("Chi Coin", "CHI") {
        require(_vault != address(0), "CHIToken: vault cannot be zero address");
        vault = _vault;
    }

    function mint(address account, uint256 amount) external onlyVault {
        require(account != address(0), "CHIToken: mint to zero address");
        require(amount > 0, "CHIToken: cannot mint zero");

        _mint(account, amount);
        emit Minted(account, amount);
    }

    function burn(address account, uint256 amount) external onlyVault {
        require(account != address(0), "CHIToken: burn from zero address");
        require(amount > 0, "CHIToken: cannot burn zero");
        require(balanceOf(account) >= amount, "CHIToken: burn amount exceeds balance");

        _burn(account, amount);
        emit Burned(account, amount);
    }
}
