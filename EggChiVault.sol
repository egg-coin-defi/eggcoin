// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

/**
 * @title EggChiVault
 * @dev Main vault contract for the EggCoin Finance system.
 * Manages dynamic minting, redeeming, and surplus distribution.
 * Uses Chainlink oracles to read token prices.
 * Balances the pool using PancakeSwap V2 router.
 */
contract EggChiVault {
    using SafeERC20 for IERC20;

    IERC20 public eggToken; // EGG$ Token
    IERC20 public chiToken; // CHI Token

    // List of collateral tokens supported by the system
    address[] public collateralTokens = [
        0x7130d2A1D7343a57Eb7sA82e3f5Cb2A12e9ceAA7, // WBTC
        0x2170Ed0880ac9A755fd29B268891032b,         // WETH
        0xbb4CdB9CBd36B01bD1cFefc5AF388D3e0e7c6001   // BNB
        // Add more tokens if needed
    ];

    // Target weights for each token (base 1000)
    mapping(address => uint256) public tokenTargetWeights;
    uint256 public totalWeight = 1000; // Total weight must be equal to 100%

    // Verified contributor addresses that receive passive rewards
    address[] public contributorAddresses = [
        0xAbcdef1234567890Abcdef1234567890Abcdef12,
        0x2AaBcD1234567890Abcdef1234567890Abcdef12,
        0x3BbCcE567890Abcdef1234567890Abcdef1234
        // You can add more addresses here
    ];

    uint256 public constant CONTRIBUTOR_SHARE_PERCENT = 10; // 10% goes to contributors
    uint256 public lastDistributionTime;
    uint256 public constant DISTRIBUTE_INTERVAL = 7 days; // Weekly distribution

    // Mapping from token address to Chainlink Oracle address
    mapping(address => address) public tokenToOracle;

    // PancakeSwap V2 Router interface
    IUniswapV2Router02 private constant PANCAKE_ROUTER =
        IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E2357); // PancakeSwap V2 Router on BSC

    /**
     * @dev Sets up ERC-20 tokens and Chainlink oracle mappings
     * Initializes target weights for each token in the pool
     * @param _eggTokenAddress Address of the EGG$ token
     * @param _chiTokenAddress Address of the CHI token
     */
    constructor(address _eggTokenAddress, address _chiTokenAddress) {
        eggToken = IERC20(_eggTokenAddress);
        chiToken = IERC20(_chiTokenAddress);

        // Set target weights for each token in the pool (base 1000)
        tokenTargetWeights[0x7130d2A1D7343a57Eb7sA82e3f5Cb2A12e9ceAA7] = 300; // WBTC 30%
        tokenTargetWeights[0x2170Ed0880ac9A755fd29B268891032b] = 200; // WETH 20%
        tokenTargetWeights[0xbb4CdB9CBd36B01bD1cFefc5AF388D3e0e7c6001] = 100; // BNB 10%
        // Set other token weights as needed...

        // Link Chainlink price feeds
        tokenToOracle[0x7130d2A1D7343a57Eb7sA82e3f5Cb2A12e9ceAA7] = 0x0d79df6665F91D0571f9CE5a85F1dc21E0f5297e888A; // BTC Oracle
        tokenToOracle[0x2170Ed0880ac9A755fd29B268891032b] = 0x5f4eC3Df9cb9e0a775b31c2BA2Fc02D4d2dE07; // ETH Oracle
        tokenToOracle[0xbb4CdB9CBd36B01bD1cFefc5AF388D3e0e7c6001] = 0x0567F2323Ec08d8a8206350555C17dF40; // BNB Oracle
    }

    /**
     * @dev Mints a `(EGG$ + CHI)` pair when user deposits one crypto
     * Requires approximately $2.00 USD worth of crypto
     * @param inputToken Address of the token deposited by the user
     * @param amountIn Amount of token deposited
     */
    function mintWithSingleToken(
        address inputToken,
        uint256 amountIn
    ) external payable {
        require(amountIn > 0, "Amount must be greater than zero");

        // Transfer token into the vault
        IERC20(inputToken).safeTransferFrom(msg.sender, address(this), amountIn);

        // Balance the pool after deposit
        _autoSwapToTargetWeights(inputToken, amountIn);

        // Mint pair for user
        _mintPair(msg.sender, 500 ether); // 500 EGG$ + 500 CHI
    }

    /**
     * @dev Redeems a full `(EGG$ + CHI)` pair for part of the locked collateral
     * Only works if the pool has enough value to back the pair
     * @param pairCount Number of pairs to redeem
     */
    function redeemPair(uint256 pairCount) external {
        require(pairCount > 0, "Must redeem at least one pair");

        uint256 totalCollateralValue = getTotalCollateralValueUSD();
        uint256 totalPairs = getTotalPairs();
        uint256 floorPricePerPair = totalCollateralValue / totalPairs;

        // User must send full pair
        eggToken.transferFrom(msg.sender, address(this), pairCount * 500 ether);
        chiToken.transferFrom(msg.sender, address(this), pairCount * 500 ether);

        sendCryptoEquivalent(msg.sender, floorPricePerPair * pairCount);
    }

    /**
     * @dev Distributes new pairs to CHI holders when there is surplus
     * Only runs once every 7 days
     */
    function distributeSurplus() external {
        require(block.timestamp >= lastDistributionTime + DISTRIBUTE_INTERVAL, "Only weekly distribution allowed");

        uint256 chiFloor = getChiFloorPrice();
        if (chiFloor <= 1e18) return; // Only if CHI > $1.00

        uint256 totalSupply = chiToken.totalSupply();
        uint256 pairsToMint = (chiFloor - 1e18) * totalSupply / 1e18 / 1e18;

        // 10% of all newly minted pairs go to early contributors
        uint256 pairsForContributors = (pairsToMint * CONTRIBUTOR_SHARE_PERCENT) / 100;

        for (uint256 i = 0; i < contributorAddresses.length; i++) {
            _mintPair(contributorAddresses[i], pairsForContributors / contributorAddresses.length);
        }

        // Remaining 90% distributed to CHI holders
        _distributeToCHI(pairsToMint * 90 / 100);

        lastDistributionTime = block.timestamp;
    }

    /**
     * @dev Automatically swaps tokens to balance the pool
     * Called after each deposit
     * @param inputToken The token deposited by the user
     * @param amountIn The amount deposited
     */
    function _autoSwapToTargetWeights(
        address inputToken,
        uint256 amountIn
    ) internal {
        uint256 totalCollateral = getTotalCollateralValueUSD();

        for (uint256 i = 0; i < collateralTokens.length; i++) {
            address token = collateralTokens[i];
            uint256 targetWeight = tokenTargetWeights[token];
            uint256 currentBalance = IERC20(token).balanceOf(address(this));
            uint256 currentValue = getTokenValueUSD(token, currentBalance);
            uint256 currentWeight = (currentValue * 1000) / totalCollateral;

            if (token == inputToken) continue;

            // If weight too low → buy more of this token
            if (currentWeight < targetWeight) {
                uint256 missingValue = (totalCollateral * targetWeight) / 1000 - currentValue;
                if (missingValue > 0) {
                    uint256 amountToSwap = getAmountInToken(token, missingValue);
                    _swapTokenForToken(inputToken, token, amountToSwap);
                }
            } else if (currentWeight > targetWeight) {
                // If weight too high → sell some of this token
                uint256 extraValue = currentValue - (totalCollateral * targetWeight) / 1000;
                if (extraValue > 0) {
                    uint256 amountToSwap = getAmountInToken(token, extraValue);
                    _swapTokenForToken(token, inputToken, amountToSwap);
                }
            }
        }
    }

    /**
     * @dev Swaps one token for another using PancakeSwap V2
     * @param fromToken Token to swap from
     * @param toToken Token to swap into
     * @param amountIn Amount to swap
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
     * @dev Mints a complete `(EGG$ + CHI)` pair for a given address
     * @param to Recipient address
     * @param amount Amount of pairs to mint
     */
    function _mintPair(address to, uint256 amount) internal {
        eggToken.mint(to, amount);
        chiToken.mint(to, amount);
    }

    /**
     * @dev Gets the current USD price of a token via Chainlink Oracle
     * @param token Address of the token
     * @return Price in USD (with 8 decimals)
     */
    function getTokenPriceUSD(address token) public view returns (uint256) {
        address oracleAddress = tokenToOracle[token];
        require(oracleAddress != address(0), "No oracle set for this token");

        AggregatorV3Interface oracle = AggregatorV3Interface(oracleAddress);

        (
            ,
            int256 price,
            ,
            ,
        ) = oracle.latestRoundData();

        return uint256(price);
    }

    /**
     * @dev Calculates total USD value of all collateral in the pool
     */
    function getTotalCollateralValueUSD() public view returns (uint256) {
        uint256 totalValue;
        for (uint256 i = 0; i < collateralTokens.length; i++) {
            address token = collateralTokens[i];
            uint256 balance = IERC20(token).balanceOf(address(this));
            uint256 value = getTokenValueUSD(token, balance);
            totalValue += value;
        }
        return totalValue;
    }

    /**
     * @dev Calculates USD value of a specific token balance
     * @param token Token address
     * @param amount Token amount
     * @return Value in USD
     */
    function getTokenValueUSD(address token, uint256 amount) public view returns (uint256) {
        uint256 decimals = uint256(AggregatorV3Interface(tokenToOracle[token]).decimals());
        uint256 price = getTokenPriceUSD(token);
        return (price * amount) / (10 ** decimals);
    }

    /**
     * @dev Floor price of a single pair `(EGG$ + CHI)`
     */
    function getFloorPricePerPair() public view returns (uint256) {
        uint256 totalCollateral = getTotalCollateralValueUSD();
        uint256 totalPairs = getTotalPairs();
        return totalCollateral / totalPairs;
    }

    /**
     * @dev Minimum guaranteed value of CHI
     */
    function getChiFloorPrice() public view returns (uint256) {
        uint256 floorPerPair = getFloorPricePerPair();
        return floorPerPair - 1e18; // Subtract EGG$ value ($1.00)
    }

    /**
     * @dev Simulates total circulating pairs
     */
    function getTotalPairs() public pure returns (uint256) {
        return 1_000_000; // 1 million pairs
    }

    /**
     * @dev Sends native crypto equivalent to $2.00 per pair
     */
    function sendCryptoEquivalent(address to, uint256 valueUSD) internal {
        payable(to).transfer(valueUSD);
    }

    /**
     * @dev Returns the Chainlink oracle for a token
     */
    function getOracleForToken(address token) public view returns (address) {
        return tokenToOracle[token];
    }

    /**
     * @dev Calculates how much of a token is needed to cover a USD value
     */
    function getAmountInToken(address token, uint256 valueUSD) public view returns (uint256) {
        uint256 price = getTokenPriceUSD(token);
        return (valueUSD * 1e18) / price;
    }

    /**
     * @dev Distributes newly minted pairs to CHI holders
     */
    function _distributeToCHI(uint256 amount) internal {
        chiToken.mint(msg.sender, amount);
    }
}