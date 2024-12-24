// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

/// @title IWETH contract interface that has all the ERC20 capabilities
/// @author Sandip Nallani
/// @notice This will be inherited by the WETH contract and then by the DepositAndWithdraw.sol contract to wrap/UnWrap user's ETH
interface IWNative {
	/// @notice balanceOf returns the balance of the account in unit
	/// @param owner , the account balance to return
	function balanceOf(address owner) external view returns (uint256);

	/// @notice approve, will approve the spender for an allowance of amount, emits Approval event, returns boolean
	/// @param spender , spender of the approved funds
	/// @param amount , amount set as allowance or approved to spend from the msg.sender
	function approve(address spender, uint amount) external returns (bool);

	/// @notice deposit, to deposit native ETH into the contract
	///@dev emits a deposit event
	function deposit() external payable;

	/**
	 * @dev Moves a `value` amount of tokens from the caller's account to `to`.
	 *
	 * Returns a boolean value indicating whether the operation succeeded.
	 *
	 * Emits a {Transfer} event.
	 */
	function transfer(address to, uint256 value) external returns (bool);

	/**
	 * @dev Returns the remaining number of tokens that `spender` will be
	 * allowed to spend on behalf of `owner` through {transferFrom}. This is
	 * zero by default.
	 *
	 * This value changes when {approve} or {transferFrom} are called.
	 */
	function allowance(
		address owner,
		address spender
	) external view returns (uint256);
}
