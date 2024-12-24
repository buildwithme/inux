// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Importing ERC20 standard contract for token creation and Ownable contract for ownership management.
import "./common/ERC20.sol";
import "./common/Ownable.sol";

//  █████                          █████ █████
// ░░███                          ░░███ ░░███ 
//  ░███  ████████   █████ ████    ░░███ ███  
//  ░███ ░░███░░███ ░░███ ░███      ░░█████   
//  ░███  ░███ ░███  ░███ ░███       ███░███  
//  ░███  ░███ ░███  ░███ ░███      ███ ░░███ 
//  █████ ████ █████ ░░████████    █████ █████

// InuX contract inherits from ERC20 and Ownable. ERC20 provides standard token functionalities,
// and Ownable provides ownership management features.
contract InuX is ERC20, Ownable {
    // Constants
    uint256 public constant MAX_SUPPLY = 8081546339 * (10 ** 18); // Sets the max token supply, representing the world population at creation.
    uint256 public constant TEMP_MAX_WALLET_HOLDING = MAX_SUPPLY / 100; // Temporary max holding per wallet (1% of total supply).
    uint256 public constant TEMP_MAX_SELL_LIMIT = MAX_SUPPLY / 100; // Temporary max sell amount at once (1% of total supply).
    uint256 public constant TEMP_COOL_DOWN_TIME = 5 minutes; // Temporary cooldown period between sells (5 minutes).

    // State variables to track temporary limits and their expiry.
    uint256 public holdingLimitExpiryTime;
    uint256 public sellLimitExpiryTime;
    uint256 public coolDownExpiryTime;

    // Flags to check if temporary limits are active.
    bool public hasTemporaryHoldingLimit = true;
    bool public hasTemporarySellLimit = true;
    bool public hasTemporaryCoolDown = true;

    // Addresses for liquidity pool and vault.
    address public liquidityPoolAddress;
    address public vaultAddress;

    // The deployer's address, used for initial setup.
    address private deployer;

    // Mapping to keep track of the last transaction time of each address.
    mapping(address => uint256) private lastTxTime;

    // Events for logging significant actions.
    event LiquidityPoolAddressSet(address indexed liquidityPoolAddress);
    event HoldingLimitDisabled();
    event SellLimitDisabled();
    event CoolDownDisabled();

    // Constructor: Sets up the token and its initial distribution.
    constructor(address _vaultAddress) ERC20("InuX", "INUX") Ownable(msg.sender) {
        require(_vaultAddress != address(0), "Vault address cannot be zero");
        deployer = msg.sender; // Setting the deployer for initial control over temporary limits.
        vaultAddress = _vaultAddress; // Setting the initial vault address.
        _mint(_vaultAddress, MAX_SUPPLY); // Minting the entire supply to the vault.
        renounceOwnership(); // Renouncing ownership to make the token fully decentralized.
    }

    // Function to set the liquidity pool address. Can only be called by the vault contract.
    function setLiquidityPoolAddress(address _liquidityPoolAddress) external {
        require(liquidityPoolAddress == address(0), "Liquidity pool address already set");
        require(vaultAddress == msg.sender, "Only vault can set liquidity pool address");
        require(_liquidityPoolAddress != address(0), "Liquidity pool address cannot be zero");

        liquidityPoolAddress = _liquidityPoolAddress; // Setting the liquidity pool address.
        emit LiquidityPoolAddressSet(_liquidityPoolAddress);

        // Initializing expiry times for temporary limits (10 days from now).
        uint256 tenDays = 10 days;
        holdingLimitExpiryTime = block.timestamp + tenDays;
        sellLimitExpiryTime = block.timestamp + tenDays;
        coolDownExpiryTime = block.timestamp + tenDays;
    }

    // Overriding the _beforeTokenTransfer hook to include checks for temporary limits.
    function _update(address from, address to, uint256 amount) internal override {
        if (liquidityPoolAddress != address(0)) {
            _applyTemporaryLimits(from, to, amount); // Applying temporary limits if set.
        }
        super._update(from, to, amount);
    }

    // Private function to enforce temporary limits.
    function _applyTemporaryLimits(address from, address to, uint256 amount) private {
        if (hasTemporaryHoldingLimit && block.timestamp <= holdingLimitExpiryTime) {
            // Enforcing max wallet holding limit.
            require(balanceOf(to) + amount <= TEMP_MAX_WALLET_HOLDING, "Exceeds max wallet holding");
        }

        if (to == liquidityPoolAddress) {
            // Enforcing sell limits for transactions to the liquidity pool.
            if (hasTemporarySellLimit && block.timestamp <= sellLimitExpiryTime) {
                require(amount <= TEMP_MAX_SELL_LIMIT, "Exceeds max sell limit");
            }

            // Enforcing cool down period for sells.
            if (hasTemporaryCoolDown && block.timestamp <= coolDownExpiryTime) {
                require(block.timestamp >= lastTxTime[from] + TEMP_COOL_DOWN_TIME, "Cool down active");
                lastTxTime[from] = block.timestamp; // Updating the last transaction time.
            }
        }
    }
 
    // Function to disable the temporary wallet holding limit. Can only be called by the deployer.
    function disableHoldingLimit() external {
		require(hasTemporaryHoldingLimit, "Holding limit already disabled");
        _requireOnlyDeployer();
        hasTemporaryHoldingLimit = false; // Disabling the holding limit.
        holdingLimitExpiryTime = block.timestamp; // Updating the expiry time.
        emit HoldingLimitDisabled();
    }

    // Function to disable the temporary sell limit. Can only be called by the deployer.
    function disableSellLimit() external {
		require(hasTemporarySellLimit, "Sell limit already disabled");
        _requireOnlyDeployer();
        hasTemporarySellLimit = false; // Disabling the sell limit.
        sellLimitExpiryTime = block.timestamp; // Updating the expiry time.
        emit SellLimitDisabled();
    }

    // Function to disable the temporary cool down period. Can only be called by the deployer.
    function disableCoolDown() external {
		require(hasTemporaryCoolDown, "Cool down already disabled");
        _requireOnlyDeployer();
        hasTemporaryCoolDown = false; // Disabling the cool down.
        coolDownExpiryTime = block.timestamp; // Updating the expiry time.
        emit CoolDownDisabled();
    }

    // Private helper function to ensure that only the deployer can perform certain actions.
    function _requireOnlyDeployer() private view {
        require(deployer == msg.sender, "Only deployer can perform this action");
    }
}
