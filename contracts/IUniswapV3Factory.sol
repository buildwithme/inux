// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

/// @title The interface for the Uniswap V3 Factory
/// @notice The Uniswap V3 Factory facilitates creation of Uniswap V3 pools and control over the protocol fees
interface IUniswapV3Factory {
	/// @notice Creates a pool for the given two tokens and fee
	/// @param tokenA One of the two tokens in the desired pool
	/// @param tokenB The other of the two tokens in the desired pool
	/// @param fee The desired fee for the pool
	/// @dev tokenA and tokenB may be passed in either order: token0/token1 or token1/token0. tickSpacing is retrieved
	/// from the fee. The call will revert if the pool already exists, the fee is invalid, or the token arguments
	/// are invalid.
	/// @return pool The address of the newly created pool
	function createPool(
		address tokenA,
		address tokenB,
		uint24 fee
	) external returns (address pool);
}
