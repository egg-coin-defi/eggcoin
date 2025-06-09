// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol"; // Using Ownable to grant minting/burning rights to the main protocol contract

/**
 * @title ChiToken
 * @dev ERC20 token for the CHI volatile asset.
 * Minting and burning capabilities are exclusively controlled by the EggChiProtocol contract.
 */
contract ChiToken is ERC20, Ownable {
    // Stores the address of the main EggChiProtocol contract, which has privileged access.
    address public eggChiProtocolAddress;

    /**
     * @dev Constructor for the ChiToken contract.
     * @param name The name of the token (e.g., "Chi Volatility Token").
     * @param symbol The symbol of the token (e.g., "CHI").
     * @param _eggChiProtocolAddress The address of the main EggChiProtocol contract.
     */
    constructor(string memory name, string memory symbol, address _eggChiProtocolAddress) ERC20(name, symbol) {
        eggChiProtocolAddress = _eggChiProtocolAddress;
    }

    /**
     * @dev Modifier to restrict function calls only to the designated EggChiProtocol contract.
     */
    modifier onlyEggChiProtocol() {
        require(msg.sender == eggChiProtocolAddress, "Caller is not the EggChiProtocol contract");
        _;
    }

    /**
     * @dev Mints new CHI tokens to a specified account.
     * Only callable by the EggChiProtocol contract.
     * @param account The address to mint tokens to.
     * @param amount The amount of tokens to mint.
     */
    function mint(address account, uint256 amount) external onlyEggChiProtocol {
        _mint(account, amount);
    }

    /**
     * @dev Burns CHI tokens from a specified account.
     * Only callable by the EggChiProtocol contract.
     * @param account The address from which to burn tokens.
     * @param amount The amount of tokens to burn.
     */
    function burn(address account, uint256 amount) external onlyEggChiProtocol {
        _burn(account, amount);
    }

    /**
     * @dev Allows the current owner (initially the deployer) to update the EggChiProtocol contract address.
     * Similar considerations as in EggToken regarding "no-governance" philosophy.
     * @param _newEggChiProtocolAddress The new address of the EggChiProtocol contract.
     */
    function setEggChiProtocolAddress(address _newEggChiProtocolAddress) external onlyOwner {
        eggChiProtocolAddress = _newEggChiProtocolAddress;
    }
}