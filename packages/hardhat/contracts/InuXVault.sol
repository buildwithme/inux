// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Importing contracts and interfaces from the local directory. These imports include the InuX token contract,
// interfaces for interacting with Wrapped Native tokens (like WETH), Uniswap V3's Factory and Position Manager,
// and standard contracts for ownership and reentrancy guard.
import "./InuX.sol";
import "./common/IWNative.sol";
import "./common/IV3Pool.sol";
import "./common/Ownable.sol";
import "./common/ReentrancyGuard.sol";
import "./common/IUniswapV3Factory.sol";
import "./common/INonfungiblePositionManager.sol";

//  █████                       █████ █████    █████   █████           ████              █████   
// ░░███                       ░░███ ░░███    ░░███   ░░███           ░░███             ░░███    
//  ░███  ████████   █████ ████ ░░███ ███      ░███    ░███   ██████   ░███  █████ ████ ███████  
//  ░███ ░░███░░███ ░░███ ░███   ░░█████       ░███    ░███  ░░░░░███  ░███ ░░███ ░███ ░░░███░   
//  ░███  ░███ ░███  ░███ ░███    ███░███      ░░███   ███    ███████  ░███  ░███ ░███   ░███    
//  ░███  ░███ ░███  ░███ ░███   ███ ░░███      ░░░█████░    ███░░███  ░███  ░███ ░███   ░███ ███
//  █████ ████ █████ ░░████████ █████ █████       ░░███     ░░████████ █████ ░░████████  ░░█████ 
// ░░░░░ ░░░░ ░░░░░   ░░░░░░░░ ░░░░░ ░░░░░         ░░░       ░░░░░░░░ ░░░░░   ░░░░░░░░    ░░░░░  
                                                                                              
                                                                                              
// The InuXVault contract is designed to manage the liquidity of InuX tokens in a decentralized finance (DeFi) environment,
// particularly with Uniswap V3. It inherits from Ownable for ownership management and ReentrancyGuard to prevent reentrancy attacks.
contract InuXVault is Ownable, ReentrancyGuard {
    // Declaring immutable variables which are set once at contract deployment and cannot be changed afterwards.
    INonfungiblePositionManager public immutable nonfungiblePositionManager;
    IWNative public wNativeToken;
    IUniswapV3Factory public uniswapFactory;
    address public inuxToken; 

    // Variable to store the address of the created liquidity pool.
    address public liquidityPool;

    // Address of the deployer of this contract. Used for initial setup and can enforce some restrictions.
    address public deployer;
    // Timestamp of contract deployment. Useful for time-based logic in the contract.
    uint256 public deployTime;

    // Boolean flag to check if the liquidity pool has been created.
    bool public isPoolCreated;

    // Variables to store the amount of InuX tokens and native tokens in the contract.
    uint256 public inuxTokenAmount;
    uint256 public contractBalance;
    uint160 public _sqrtPriceX96;

    // Address representing a burned address. Tokens sent to this address are effectively removed from circulation.
    address burnedAddress = 0x000000000000000000000000000000000000dEaD;

    // Events to log various activities within the contract.
    event Received(address sender, uint256 amount);
    event BurnedLiquidityToken(address operator, uint256 tokenId);

    // Constructor: Sets initial configuration of the contract.
    constructor(
        INonfungiblePositionManager _nonfungiblePositionManager,
        IUniswapV3Factory _factory,
        IWNative _wNativeToken,
        address _inuxToken
    )  Ownable(msg.sender){
        nonfungiblePositionManager = _nonfungiblePositionManager; // Setting up the Nonfungible Position Manager for managing Uniswap V3 positions.
        uniswapFactory = _factory; // Setting up the Uniswap V3 Factory for creating liquidity pools.
        wNativeToken = _wNativeToken; // Wrapped Native Token interface, such as WETH for Ethereum.
        inuxToken = _inuxToken; // Address of the InuX token.

        deployer = msg.sender; // Storing the address of the contract deployer.
        deployTime = block.timestamp; // Recording the deployment time for time-based logic.

        renounceOwnership(); // Renouncing ownership to make the contract fully decentralized post-deployment.
    }

    // Fallback function to receive native tokens: Essential for the contract to receive and hold native blockchain tokens.
    receive() external payable {
        require(!isPoolCreated, "Initial pool already created"); // Ensure no native tokens are received after pool creation.

        wNativeToken.deposit{ value: msg.value }(); // Wrapping the received native tokens as WNative tokens.

        emit Received(msg.sender, msg.value); // Emitting an event to log the receipt of native tokens.
    }

    // Function to create a liquidity pool and add liquidity: Key function for initializing the DeFi interaction of InuX tokens.
    function createPoolAndAddLiquidity() external nonReentrant() {
        require(!isPoolCreated, "Initial pool already created"); // Ensure the pool is not already created.

        // Enforcing a time-based or deployer-based restriction for creating the pool.
        require(
            deployer == msg.sender || block.timestamp > deployTime + 10 days,
            "Cannot create pool yet"
        );

        contractBalance = wNativeToken.balanceOf(address(this)); // Fetching the balance of wrapped native tokens in the contract.
        require(contractBalance > 0, "No native tokens to add to the pool"); // Ensure there are tokens to add to the pool.

        // Approving the Nonfungible Position Manager to use the wrapped native tokens.
        wNativeToken.approve(address(nonfungiblePositionManager), contractBalance); 

        InuX inux = InuX(inuxToken); // Instantiating the InuX token contract.
        inuxTokenAmount = inux.balanceOf(address(this)); // Fetching the InuX token balance of this contract.

        // Approving the Nonfungible Position Manager to use InuX tokens.
        inux.approve(address(nonfungiblePositionManager), inuxTokenAmount); 

        uint24 poolFee = 3000; // Setting the pool fee to 0.03%.

        // Creating the liquidity pool on Uniswap V3.
        liquidityPool = uniswapFactory.createPool(address(wNativeToken), inuxToken, poolFee);
        require(liquidityPool != address(0), "Failed to create pool");
        
        isPoolCreated = true; // Marking the pool as created.

        // Calculating the square root price for initializing the pool.
        _sqrtPriceX96 = calculateSqrtPriceX96(inuxTokenAmount, contractBalance);

        // Initializing the liquidity pool with the calculated square root price.
        IV3Pool(liquidityPool).initialize(_sqrtPriceX96);

        // Configuring parameters for adding liquidity.
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: address(wNativeToken),
            token1: inuxToken,
            fee: poolFee,
            tickLower: -887220,
            tickUpper: 887220,
            amount0Desired: contractBalance,
            amount1Desired: inuxTokenAmount,
            amount0Min: (contractBalance * 9999) / 10000,
            amount1Min: (inuxTokenAmount * 9999) / 10000,
            recipient: burnedAddress,
            deadline: block.timestamp
        });

        nonfungiblePositionManager.mint(params); // Minting the liquidity position.

        // Updating the InuX contract with the newly created liquidity pool address.
        inux.setLiquidityPoolAddress(liquidityPool);
    }

    // Private function to calculate the square root price ratio: This is a critical step in pool initialization.
    function calculateSqrtPriceX96(uint256 amountInuX, uint256 amountNativeTokens) private pure returns (uint160) {
        require(amountInuX > 0 && amountNativeTokens > 0, "Amounts must be greater than zero");

        // Calculating the price of one InuX token in terms of native tokens.
        uint256 priceInuXPerNativeToken = amountInuX / amountNativeTokens;

        // Calculating the square root of the price ratio.
        uint256 sqrtPrice = sqrt(priceInuXPerNativeToken);

        // Converting the square root price to a 96-bit fixed-point format, as required by Uniswap V3.
        uint256 sqrtPriceX96 = sqrtPrice << 96;

        return uint160(sqrtPriceX96); // Casting to uint160, the type expected by Uniswap V3.
    }

    // Helper function to compute the square root of a number: Utilizes a numerical method for square root approximation.
    function sqrt(uint256 y) private pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1; // Initial approximation.
            while (x < z) { // Iterative refinement of the approximation.
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1; // For small numbers, the square root is approximated as 1.
        }
        // else z = 0 (default value, for y = 0)
    }
}
