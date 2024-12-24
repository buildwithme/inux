// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./InuX.sol";
import "./Ownable.sol";
import "./IWNative.sol";
import "./ReentrancyGuard.sol";
import "./IUniswapV3Factory.sol";
import "./INonfungiblePositionManager.sol";

import "hardhat/console.sol";

interface IV3Pool {
	function initialize(uint160 _sqrtPriceX96) external;

	function slot0()
		external
		view
		returns (
			uint160 sqrtPriceX96,
			int24 tick,
			uint16 observationIndex,
			uint16 observationCardinality,
			uint16 observationCardinalityNext,
			uint32 feeProtocol,
			bool unlocked
		);
}

contract LiquidityPoolManager is Ownable, ReentrancyGuard {
	INonfungiblePositionManager public immutable nonfungiblePositionManager;
	IWNative public wNative;
	IUniswapV3Factory public uniswapFactory;
	InuX public inuxToken;

	address public deployer;

	bool public isPoolCreated;

	uint24 public poolFee = 3000; // 0.03%

	uint256 public coconuntTokenAmount;
	uint256 public initialWrappedNativeBalance;
	uint160 public _sqrtPriceX96;
	address public liquidityPoolCreated;

	uint256 public mintedLiquidityPoolTokenId;

	// Event to emit when native tokens are received
	event Received(address sender, uint256 amount);

	constructor(
		INonfungiblePositionManager _nonfungiblePositionManager,
		IUniswapV3Factory _factory,
		IWNative _wNative,
		InuX _inuxToken
	) Ownable(msg.sender) {
		nonfungiblePositionManager = _nonfungiblePositionManager;

		uniswapFactory = _factory;

		wNative = _wNative;

		inuxToken = _inuxToken;

		// deployer is only used to call the createPool function
		deployer = msg.sender;

		// deployer ownership is renounced after the initial minting
		renounceOwnership();
	}

	// Function to receive native tokens and wrapping them. msg.data must be empty
	receive() external payable {
		// require that the pool to not be created
		require(!isPoolCreated, "Initial pool already created");

		wNative.deposit{ value: msg.value }();

		// emit an event to notify that native tokens have been received
		emit Received(msg.sender, msg.value);
	}

	// Function create the pool and add initial liquidity
	function createPoolAndAddInitialLiquidity() external nonReentrant {
		require(!isPoolCreated, "Initial pool already created");

		// Get the entire balance of wrapped native tokens held by the contract
		initialWrappedNativeBalance = wNative.balanceOf(address(this));
		require(
			initialWrappedNativeBalance > 0,
			"No wrapped tokens to add to the pool"
		);

		// Approve the position manager to spend wrapped native tokens
		wNative.approve(
			address(nonfungiblePositionManager),
			initialWrappedNativeBalance
		);

		// Get the entire balance of InuX tokens held by the contract
		// the contract will have the entire supply of InuX tokens
		coconuntTokenAmount = inuxToken.balanceOf(address(this));

		// Approve the position manager to spend InuX tokens
		inuxToken.approve(
			address(nonfungiblePositionManager),
			coconuntTokenAmount
		);

		// Create the pool
		liquidityPoolCreated = uniswapFactory.createPool(
			address(inuxToken),
			address(wNative),
			poolFee
		);

		// Check that the pool was created
		require(liquidityPoolCreated != address(0), "Pool creation failed");

		// Indicate that the pool has been created
		isPoolCreated = true;

		// Calculate the square root price X96
		_sqrtPriceX96 = calculateSqrtPriceX96(
			coconuntTokenAmount,
			initialWrappedNativeBalance
		);

		console.log("sqrtPriceX96: %s", _sqrtPriceX96);

		// Initialize the pool with the calculated square root price X96
		IV3Pool(liquidityPoolCreated).initialize(_sqrtPriceX96);

		console.log("Pool created %s", liquidityPoolCreated);

		// Set the parameters for your liquidity position
		INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager
			.MintParams({
				token0: address(inuxToken),
				token1: address(wNative),
				fee: poolFee,
				tickLower: -887220,
				tickUpper: 887220,
				amount0Desired: coconuntTokenAmount,
				amount1Desired: initialWrappedNativeBalance,
				// The minimum amounts of token0 and token1 liquidity to mint 99.99%
				amount0Min: coconuntTokenAmount - (coconuntTokenAmount / 10000),
				amount1Min: initialWrappedNativeBalance -
					(initialWrappedNativeBalance / 10000),
				// liquitity tokens will be automatically burned
				recipient: address(0),
				deadline: block.timestamp + 15 minutes
			});

		// Mint liquidity
		(uint256 tokenId, , , ) = nonfungiblePositionManager.mint(params);

		console.log("Liquidity minted %s", tokenId);

		// Set the minted liquidity pool token id
		mintedLiquidityPoolTokenId = tokenId;
		console.log(
			"mintedLiquidityPoolTokenId: %s",
			mintedLiquidityPoolTokenId
		);

		// Set the liquidity pool address in the InuX token
		inuxToken.setLiquidityPoolAddress(liquidityPoolCreated);
	}

	// Function to calculate the square root price X96
	function calculateSqrtPriceX96(
		uint256 amountInuXTokens,
		uint256 amountNativeTokens
	) internal pure returns (uint160) {
		require(
			amountInuXTokens > 0 && amountNativeTokens > 0,
			"Amounts must be greater than zero"
		);

		uint256 priceInuXPerNativeTokens = amountInuXTokens /
			amountNativeTokens;

		// Calculate the square root of the price ratio
		uint256 sqrtPrice = sqrt(priceInuXPerNativeTokens);

		// Adjust to 96-bit fixed-point number
		uint256 sqrtPriceX96 = sqrtPrice << 96;

		// Convert to uint160 (fitting it into the correct type)
		return uint160(sqrtPriceX96);
	}

	// Helper function to calculate square root
	function sqrt(uint256 y) internal pure returns (uint256 z) {
		if (y > 3) {
			z = y;
			uint256 x = y / 2 + 1;
			while (x < z) {
				z = x;
				x = (y / x + x) / 2;
			}
		} else if (y != 0) {
			z = 1;
		}
		// else z = 0 (default value)
	}
}
