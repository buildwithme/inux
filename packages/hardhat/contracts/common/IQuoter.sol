// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

/// @title Quoter Interface
/// @notice Supports quoting the calculated amounts from exact input or exact output swaps
/// @dev These functions are not marked view because they rely on calling non-view functions and reverting
/// to compute the result. They are also not gas efficient and should not be called on-chain.
interface IQuoter {
	/// @notice Returns the amount in required to receive the given exact output amount but for a swap of a single pool
	/// @param tokenIn The token being swapped in
	/// @param tokenOut The token being swapped out
	/// @param fee The fee of the token pool to consider for the pair
	/// @param amountOut The desired output amount
	/// @param sqrtPriceLimitX96 The price limit of the pool that cannot be exceeded by the swap
	/// @return amountIn The amount required as the input for the swap in order to receive `amountOut`
	function quoteExactOutputSingle(
		address tokenIn,
		address tokenOut,
		uint24 fee,
		uint256 amountOut,
		uint160 sqrtPriceLimitX96
	) external returns (uint256 amountIn);
}
