// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Interfaces
import "./interfaces/ISwapRouter.sol";
import "./interfaces/IWETH9.sol";
import "./interfaces/IUniswapV3Factory.sol";
import "./interfaces/IERC20Minimal.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// Define the contract with necessary interfaces and libraries
contract UniswapBot is ReentrancyGuard {
    // Declare variables
    ISwapRouter public uniswapV3Router;
    IUniswapV3Factory public uniswapV3Factory;
    IERC20Minimal public token;
    IWETH9 public WETH;
    address private owner;
    uint256 public launchTimestamp;
    uint256 public tradingWindow = 1800; // 30 minutes
    bool public emergencyStopActive = false;

    // Define events
    event SwapETHForTokens(uint256 ethAmount, uint256 tokensReceived);
    event SwapTokensForETH(uint256 tokenAmount, uint256 ethReceived);

    event Withdraw(uint256 tokenAmount, uint256 ethAmount);
    event EmergencyStopTriggered(bool isActive);

    // Define modifiers
    modifier onlyOwner() {
        // Ensure only the owner can call the function
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    modifier withinTradingWindow() {
        // Ensure trading is allowed only within the trading window
        require(
            block.timestamp <= launchTimestamp + tradingWindow,
            "Trading allowed only within the trading window"
        );
        _;
    }

    modifier notInEmergency() {
        // Ensure the emergency stop is not active
        require(!emergencyStopActive, "Emergency stop is active");
        _;
    }

    // Define constructor
    constructor(
        address _tokenAddress,
        address _uniswapV3RouterAddress,
        address _uniswapV3FactoryAddress,
        address _WETHAddress,
        uint256 _launchTimestamp,
        uint256 _tradingWindow
    ) {
        require(_tradingWindow > 0, "Trading window must be greater than 0");

        // Initialize variables in constructor
        uniswapV3Router = ISwapRouter(_uniswapV3RouterAddress);
        uniswapV3Factory = IUniswapV3Factory(_uniswapV3FactoryAddress);
        token = IERC20Minimal(_tokenAddress);
        owner = msg.sender;
        WETH = IWETH9(_WETHAddress);
        launchTimestamp = _launchTimestamp;
        tradingWindow = _tradingWindow;
    }

    // Function to get the ETH balance of the contract
    function getETHBalance() public view returns (uint256) {
        return address(this).balance;
    }

//   // Function to get a quote for token swapping
// function getQuote(
//     uint256 amountIn,
//     address tokenIn,
//     address tokenOut,
//     uint24 fee
// ) public view returns (uint256 amountOut) {
//     // Replace this function with your own implementation using an off-chain
//     // service like the Uniswap SDK to fetch quotes for token swaps.
//     // This is just a placeholder.
//     amountIn - (fee );
//     tokenIn;
//     tokenOut;
//     // Define the path for the swap
//     uint24 chosenFee = 3000; // Choose the appropriate fee tier (e.g., 500, 3000, or 10000)
//     amountOut = 1;
// }



    // External function to swap ETH for tokens a.k.a The Buy Function
    function swapETHForTokens(
        uint256 slippageTolerance
    ) external payable nonReentrant withinTradingWindow notInEmergency {
        require(
            slippageTolerance >= 0 && slippageTolerance <= 10000,
            "Invalid slippage tolerance"
        );

        uint256 ethAmount = msg.value;

        // Define the path for the swap
        address tokenIn = address(WETH); // TokenIn - The Token from the LP should be coming here 
        address tokenOut = address(token);

        uint24 fee = 3000; // Choose the appropriate fee tier (e.g., 500, 3000, or 10000)

    //         // Get the quote for the expected amount of tokens to receive
    // uint256 tokensOut = getQuote(ethAmount, tokenIn, tokenOut, fee);

    // // Calculate the minimum amount of tokens to receive based on the slippage tolerance
    // uint256 minTokens = (tokensOut * (10000 - slippageTolerance)) / 10000;
    uint256 minTokens = 666666; // Set a fixed minimum tokens to receive, change as needed
    // Perform the swap
    try
        uniswapV3Router.exactInputSingle{value: ethAmount}(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: fee,
                recipient: address(this),
                deadline: block.timestamp + 300, // 5 minutes
                amountIn: ethAmount,
                amountOutMinimum: minTokens,
                sqrtPriceLimitX96: 0
            })
        )
    returns (uint256 tokensReceived) {
        require(
            tokensReceived >= minTokens,
            "Received less tokens than expected"
        );

        emit SwapETHForTokens(ethAmount, tokensReceived);
    } catch Error(string memory reason) {
        // Handle errors from Uniswap router
        revert(reason);
    } catch {
        revert("Swap failed");
    }
}

// External function to swap tokens for ETH a.k.a The Sell Function
function swapTokensForETH(
    uint256 tokenAmount,
    uint256 slippageTolerance
) external nonReentrant withinTradingWindow notInEmergency {
    require(tokenAmount > 0, "Token amount must be greater than 0");
    require(
        slippageTolerance >= 0 && slippageTolerance <= 10000,
        "Invalid slippage tolerance"
    );

    // Transfer tokens from the sender to the contract
    token.transferFrom(msg.sender, address(this), tokenAmount);

    // Define the path for the swap
    address tokenIn = address(token);
    address tokenOut = address(WETH);

    uint24 fee = 3000; // Choose the appropriate fee tier (e.g., 500, 3000, or 10000)

    // Approve the Uniswap router to spend tokens
    token.approve(address(uniswapV3Router), tokenAmount);

    // // Get the quote for the expected amount of ETH to receive
    // uint256 ethOut = getQuote(tokenAmount, tokenIn, tokenOut, fee);

    // // Calculate the minimum amount of ETH to receive based on the slippage tolerance
    // uint256 minEth = (ethOut * (10000 - slippageTolerance)) / 10000;

    uint256 minEth = 1; // Set a fixed minimum ETH to receive, change as needed


    // Perform the swap
    try
        uniswapV3Router.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: fee,
                recipient: msg.sender, // Send the received ETH directly to the sender
                deadline: block.timestamp + 300, // 5 minutes
                amountIn: tokenAmount,
                amountOutMinimum: minEth,
                sqrtPriceLimitX96: 0
            })
        )
    returns (uint256 ethReceived) {
        require(ethReceived >= minEth, "Received less ETH than expected");

        emit SwapTokensForETH(tokenAmount, ethReceived);
    } catch Error(string memory reason) {
        // Handle errors from Uniswap router
        revert(reason);
    } catch {
        revert("Swap failed");
    }
}


   

    // Function to withdraw tokens and ETH
    function withdraw() public onlyOwner {
        // Get the balance of the contract
        uint256 tokenBalance = token.balanceOf(address(this));
        uint256 ethBalance = address(this).balance;

        // Transfer the tokens and ETH to the owner
        token.transfer(owner, tokenBalance);
        payable(owner).transfer(ethBalance);

        // Emit event
        emit Withdraw(tokenBalance, ethBalance);
    }

    // Function to trigger emergency stop
    function triggerEmergencyStop() public onlyOwner {
        // Toggle the emergency stop status
        emergencyStopActive = !emergencyStopActive;

        // Emit event
        emit EmergencyStopTriggered(emergencyStopActive);
    }
}