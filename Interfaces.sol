// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title AggregatorV3Interface
 * @dev Interface for Chainlink Price Feeds. Used to get asset prices.
 * Functions like `latestRoundData()` are crucial for price retrieval and validity checks.
 */
interface AggregatorV3Interface {
    function decimals() external view returns (uint8);
    function description() external view returns (string memory);
    function version() external view returns (uint256);
    function getRoundData(uint80 _roundId)
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

/**
 * @title IDexRouter
 * @dev Interface for a standard Decentralized Exchange (DEX) Router (e.g., PancakeSwap Router V2).
 * Used to perform token swaps.
 */
interface IDexRouter {
    function factory() external pure returns (address);
    function WETH() external pure returns (address); // On BSC, this would typically be WBNB

    /**
     * @dev Swaps an exact amount of `amountIn` of one token for `amountOutMin` of another.
     * @param amountIn The amount of tokens to send.
     * @param amountOutMin The minimum amount of tokens to receive (for slippage control).
     * @param path An array of token addresses, ordered by the route. e.g. [tokenA, tokenB]
     * @param to The recipient of the output tokens.
     * @param deadline The timestamp by which the swap must be executed.
     */
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    /**
     * @dev Swaps a maximum amount of `amountInMax` of one token for an exact `amountOut` of another.
     * @param amountOut The exact amount of tokens to receive.
     * @param amountInMax The maximum amount of tokens to send (for slippage control).
     * @param path An array of token addresses, ordered by the route. e.g. [tokenA, tokenB]
     * @param to The recipient of the output tokens.
     * @param deadline The timestamp by which the swap must be executed.
     */
    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    // Other common DEX router functions like `getAmountsOut`, `getAmountsIn` might be needed
    // for calculating expected swap outcomes before execution.
}

/**
 * @title IERC20
 * @dev Minimal interface for an ERC-20 token. Used for interacting with collateral tokens.
 */
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}