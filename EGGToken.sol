// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title EGGToken
 * @dev Trustless stablecoin soft-pegged to $1, mintable/burnable only by vault
 */
contract EGGToken is ERC20 {
    address public immutable vault;

    event Minted(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);

    modifier onlyVault() {
        require(msg.sender == vault, "EGGToken: caller is not the vault");
        _;
    }

    constructor(address _vault) ERC20("Egg Dollar", "EGG$") {
        require(_vault != address(0), "EGGToken: vault cannot be zero address");
        vault = _vault;
    }

    function mint(address account, uint256 amount) external onlyVault {
        require(account != address(0), "EGGToken: mint to zero address");
        require(amount > 0, "EGGToken: cannot mint zero");

        _mint(account, amount);
        emit Minted(account, amount);
    }

    function burn(address account, uint256 amount) external onlyVault {
        require(account != address(0), "EGGToken: burn from zero address");
        require(amount > 0, "EGGToken: cannot burn zero");
        require(balanceOf(account) >= amount, "EGGToken: burn amount exceeds balance");

        _burn(account, amount);
        emit Burned(account, amount);
    }
}
