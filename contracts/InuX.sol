// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ERC20.sol";
import "./Ownable.sol";

contract InuX is ERC20, Ownable {
	// maximum supply of the InuX token
	// represents the number of people in the world at the time of creation
	uint256 public constant MAX_SUPPLY = 8080431451 * (10 ** 18);

	// temporary limit to prevent whales from buying too much
	uint256 public constant TEMPORARY_MAX_WALLET_HOLDING =
		(MAX_SUPPLY * 1) / 100; // 1% of total supply

	// temporary limit to prevent whales from selling too much at a time
	uint256 public constant TEMPORARY_MAX_SELL_LIMIT = (MAX_SUPPLY * 1) / 100; // 1% of total supply

	// temporary cool down time to prevent whales from selling too fast
	uint256 public TEMPORARY_COOL_DOWN_TIME = 5 minutes;

	uint256 public holdingLimitExpiryTime;
	uint256 public sellLimitExpiryTime;
	uint256 public coolDownExpiryTime;

	bool hasTemporaryHoldingLimit = true;
	bool hasTemporarySellLimit = true;
	bool hasTemporaryCoolDown = true;

	address public liquidityPoolAddress;
	address public vaultAddress;
	address public deployer;

	mapping(address => uint256) private _lastTxTime;

	constructor(
		address _vaultAddress
	) ERC20("InuX", "INUX") Ownable(msg.sender) {
		// deployer is only used to disable the remporary holding limit, sell limit and cool down one time
		deployer = msg.sender;

		// set the vault address
		vaultAddress = _vaultAddress;

		// mint all tokens to the vault address
		_mint(_vaultAddress, MAX_SUPPLY);

		// deployer ownership is renounced after the initial minting
		renounceOwnership();
	}

	function setLiquidityPoolAddress(address _liquidityPoolAddress) public {
		require(
			liquidityPoolAddress == address(0),
			"Liquidity pool address already set"
		);

		require(
			vaultAddress == msg.sender,
			"Only the vault contract can set liquidity pool address"
		);

		liquidityPoolAddress = _liquidityPoolAddress;

		holdingLimitExpiryTime = block.timestamp + 10 days;
		sellLimitExpiryTime = block.timestamp + 10 days;
		coolDownExpiryTime = block.timestamp + 10 days;
	}

	function _update(
		address from,
		address to,
		uint256 amount
	) internal override {
		super._update(from, to, amount);

		// no need to check yet if liquidity pool address is set
		// the entire supply is initially minted to the liquidity pool
		if (liquidityPoolAddress == address(0)) {
			return;
		}

		// Temporarty wallet holding limit
		if (
			hasTemporaryHoldingLimit || holdingLimitExpiryTime > block.timestamp
		) {
			// Not applicable for initial minted tokens
			require(
				balanceOf(to) + amount <= TEMPORARY_MAX_WALLET_HOLDING,
				"Temporary wallet holding limit exceeded"
			);
		}

		// Apply cool-down and holding limit only for sales from the liquidity pool
		if (to == liquidityPoolAddress) {
			// Sell limit
			if (
				hasTemporarySellLimit || sellLimitExpiryTime > block.timestamp
			) {
				require(
					amount <= TEMPORARY_MAX_SELL_LIMIT,
					"Temporary sell limit exceeded"
				);
			}

			// Cool down
			if (hasTemporaryCoolDown || coolDownExpiryTime > block.timestamp) {
				require(
					block.timestamp >=
						_lastTxTime[from] + TEMPORARY_COOL_DOWN_TIME,
					"Temporary cool down period active"
				);
				_lastTxTime[from] = block.timestamp;
			}
		}
	}

	function disableHoldingLimit() public {
		require(hasTemporaryHoldingLimit, "Holding limit already disabled");

		require(
			deployer == msg.sender,
			"Only deployer can disable holding limit"
		);

		hasTemporaryHoldingLimit = false;
		holdingLimitExpiryTime = block.timestamp;
	}

	function disableSellLimit() public {
		require(hasTemporarySellLimit, "Sell limit already disabled");

		require(deployer == msg.sender, "Only deployer can disable sell limit");

		hasTemporarySellLimit = false;
		sellLimitExpiryTime = block.timestamp;
	}

	function disableCoolDown() public {
		require(hasTemporaryCoolDown, "Cool down already disabled");

		require(deployer == msg.sender, "Only deployer can disable cool down");

		hasTemporaryCoolDown = false;
		coolDownExpiryTime = block.timestamp;
	}
}
