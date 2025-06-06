// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

/**
 * @title EggChiVault
 * @dev Main vault contract for the EggCoin Finance system.
 * Manages dynamic minting, redeeming, and surplus distribution.
 * Fully decentralized – no admin or owner functions.
 */
contract EggChiVault {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public eggToken;
    IERC20 public chiToken;

    // List of supported collateral tokens in the pool
    address[] public collateralTokens = [
        0x7130d2A1D7343a57Eb7sA82e3f5Cb2A12e9ceAA7, // WBTC
        0x2170Ed0880ac9A755fd29B268891032b,         // WETH
        0xbb4CdB9CBd36B01bD1cFefc5AF388D3e0e7c6001      // BNB
        // Add more tokens as needed
    ];

    // Target weights for each token in the pool (base 1000)
    mapping(address => uint256) public tokenTargetWeights; // e.g., 300 = 30%
    uint256 public totalWeight = 1000; // Total weight must equal 100%

    // PancakeSwap router for automated swaps
    IUniswapV2Router02 private constant PANCAKE_ROUTER =
        IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E2357); // PancakeSwap Router V2 on BSC

    // Verified contributors who will receive a share of surplus
    address[] public contributorAddresses = [
        0xAbcdef1234567890Abcdef1234567890Abcdef12,
        0x2AaBcD1234567890Abcdef1234567890Abcdef12,
        0x3BbCcE567890Abcdef1234567890Abcdef1234
        // Add remaining 97 addresses here
    ];

    uint256 public constant CONTRIBUTOR_SHARE_PERCENT = 10; // 10% goes to contributors
    uint256 public lastDistributionTime;
    uint256 public constant DISTRIBUTE_INTERVAL = 7 days; // Weekly distribution

    /**
     * @dev Initializes the contract with EGG$ and CHI token addresses
     * Sets the target weights for each token in the collateral pool
     */
    constructor(address _eggTokenAddress, address _chiTokenAddress) {
        eggToken = IERC20(_eggTokenAddress);
        chiToken = IERC20(_chiTokenAddress);

        // Set target weights for each token in the pool (base 1000)
        tokenTargetWeights[0x7130d2A1D7343a57Eb7sA82e3f5Cb2A12e9ceAA7] = 300; // WBTC 30%
        tokenTargetWeights[0x2170Ed0880ac9A755fd29B268891032b] = 200; // WETH 20%
        tokenTargetWeights[0xbb4CdB9CBd36B01bD1cFefc5AF388D3e0e7c6001] = 100; // BNB 10%
        // Set other token weights as needed
    }

    /**
     * @dev Mints an `(EGG$ + CHI)` pair when user deposits one crypto
     * Automatically balances the pool by swapping tokens if necessary
     * @param inputToken Address of the token deposited by the user
     * @param amountIn Amount of token deposited
     */
    function mintWithSingleToken(
        address inputToken,
        uint256 amountIn
    ) external payable {
        require(amountIn > 0, "Amount must be greater than zero");

        // Transfer the input token into the vault
        IERC20(inputToken).safeTransferFrom(msg.sender, address(this), amountIn);

        // Get current values from the pool
        uint256[] memory currentBalances = new uint256[](collateralTokens.length);
        for (uint256 i = 0; i < collateralTokens.length; i++) {
            currentBalances[i] = IERC20(collateralTokens[i]).balanceOf(address(this));
        }

        uint256 totalCollateralValue = getTotalCollateralValueUSD();
        uint256 totalPairs = getTotalPairs();

        uint256 floorPricePerPair = totalCollateralValue / totalPairs;

        // Auto-swap to balance the pool after deposit
        _autoSwapToTargetWeights(inputToken, amountIn);

        // Mint pair for user
        _mintPair(msg.sender, 500 ether); // 500 EGG$ + 500 CHI
    }

    /**
     * @dev Balances the pool by swapping tokens via PancakeSwap
     * Called after deposit to maintain correct allocation
     * @param inputToken Token received from user
     * @param amountIn Amount of input token
     */
    function _autoSwapToTargetWeights(
        address inputToken,
        uint256 amountIn
    ) internal {
        uint256 totalCollateralValue = getTotalCollateralValueUSD();

        // For each token in the pool:
        for (uint256 i = 0; i < collateralTokens.length; i++) {
            address token = collateralTokens[i];
            uint256 targetWeight = tokenTargetWeights[token];
            uint256 currentBalance = IERC20(token).balanceOf(address(this));
            uint256 currentValue = getTokenValueUSD(token, currentBalance);
            uint256 currentWeight = (currentValue * 1000) / totalCollateralValue;

            if (token == inputToken) continue;

            // If below target → swap into this token
            if (currentWeight < targetWeight) {
                uint256 missingValue = (totalCollateralValue * targetWeight) / 1000 - currentValue;

                if (missingValue > 0) {
                    uint256 amountToSwap = getAmountInToken(inputToken, missingValue);
                    _swapTokenForToken(inputToken, token, amountToSwap);
                }
            } else if (currentWeight > targetWeight) {
                // If above target → swap out of this token
                uint256 extraValue = currentValue - (totalCollateralValue * targetWeight) / 1000;

                if (extraValue > 0) {
                    uint256 amountToSwap = getAmountInToken(token, extraValue);
                    _swapTokenForToken(token, inputToken, amountToSwap);
                }
            }
        }
    }

    /**
     * @dev Swaps one token for another using PancakeSwap
     * @param fromToken Token to swap from
     * @param toToken Token to swap into
     * @param amountIn Amount of token to swap
     */
    function _swapTokenForToken(
        address fromToken,
        address toToken,
        uint256 amountIn
    ) internal {
        require(fromToken != toToken, "Same token not allowed");

        IERC20(fromToken).approve(address(PANCAKE_ROUTER), amountIn);

        address[] memory path = new address[](2);
        path[0] = fromToken;
        path[1] = toToken;

        PANCAKE_ROUTER.swapExactTokensForTokens(
            amountIn,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    /**
     * @dev Mints a complete `(EGG$ + CHI)` pair
     * @param to Address to receive the pair
     * @param amount Number of pairs to mint
     */
    function _mintPair(address to, uint256 amount) internal {
        eggToken.mint(to, amount);
        chiToken.mint(to, amount);
    }

    /**
     * @dev Calculates USD value of a token based on oracle price
     * @param token Token address
     * @param amount Token amount
     * @return USD value of the token
     */
    function getTokenValueUSD(address token, uint256 amount) public view returns (uint256) {
        return amount.mul(getOraclePrice(token)).div(1e18);
    }

    /**
     * @dev Returns simulated oracle price for a token
     * In production, replace with Chainlink or TWAP
     * @param token Token address
     * @return Price in USD (with 18 decimals)
     */
    function getOraclePrice(address token) public pure returns (uint256) {
        if (token == 0x7130d2A1D7343a57Eb7sA82e3f5Cb2A12e9ceAA7) {
            return 30_000e18; // WBTC = $30,000
        }
        return 1e18; // Default: $1.00
    }

    /**
     * @dev Simulates total value of all collateral in USD
     * Replace with real data in production
     */
    function getTotalCollateralValueUSD() public pure returns (uint256) {
        return 2_000_000e18; // $2.000.000
    }

    /**
     * @dev Simulates total circulating pairs
     * Replace with real data in production
     */
    function getTotalPairs() public pure returns (uint256) {
        return 1_000_000; // 1 million pairs
    }

    /**
     * @dev Distributes surplus to CHI holders and contributors
     * Only runs once every 7 days
     */
    function distributeSurplus() external {
        require(block.timestamp >= lastDistributionTime + DISTRIBUTE_INTERVAL, "Only weekly distribution allowed");

        uint256 chiFloor = getChiFloorPrice();
        if (chiFloor <= 1e18) return;

        uint256 totalSupply = chiToken.totalSupply();
        uint256 pairsToMint = (chiFloor.sub(1e18)).mul(totalSupply).div(1e18).div(1e18);

        // 10% of rewards go to early contributors
        uint256 pairsForContributors = (pairsToMint * CONTRIBUTOR_SHARE_PERCENT) / 100;

        for (uint256 i = 0; i < contributorAddresses.length; i++) {
            _mintPair(contributorAddresses[i], pairsForContributors / contributorAddresses.length);
        }

        // Remaining 90% distributed to CHI holders
        _distributeToCHI(pairsToMint * 90 / 100);

        lastDistributionTime = block.timestamp;
    }

    /**
     * @dev Distributes newly minted pairs to CHI holders
     * In production, use proportional logic and snapshots
     */
    function _distributeToCHI(uint256 amount) internal {
        chiToken.mint(msg.sender, amount);
    }

    /**
     * @dev Floor price of CHI is derived from the pool
     * Calculated as: floor price of pair minus EGG$ value
     */
    function getChiFloorPrice() public view returns (uint256) {
        uint256 floorPerPair = getTotalCollateralValueUSD().div(getTotalPairs());
        return floorPerPair.sub(1e18); // Subtract EGG$ value
    }
}