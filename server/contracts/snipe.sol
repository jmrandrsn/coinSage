// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Interfaces
import "https://github.com/Uniswap/v3-periphery/blob/main/contracts/interfaces/ISwapRouter.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/security/ReentrancyGuard.sol";

// Define the contract with necessary interfaces and libraries
contract UniswapBot is ReentrancyGuard {
    // Declare variables
    ISwapRouter public uniswapV3Router;
    IERC20 public token;
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
        uint256 _launchTimestamp,
        uint256 _tradingWindow
    ) {
        require(_tradingWindow > 0, "Trading window must be greater than 0");

        // Initialize variables in constructor
        uniswapV3Router = ISwapRouter(_uniswapV3RouterAddress);
        token = IERC20(_tokenAddress);
        owner = msg.sender;
        launchTimestamp = _launchTimestamp;
        tradingWindow = _tradingWindow;
    }

    // Function to get the ETH balance of the contract
    function getETHBalance() public view returns (uint256) {
        return address(this).balance;
    }

    // External function to swap ETH for tokens
    function swapETHForTokens(
        uint256 slippageTolerance
    ) external payable nonReentrant withinTradingWindow notInEmergency {
        require(
            slippageTolerance >= 0 && slippageTolerance <= 10000,
            "Invalid slippage tolerance"
        );

        uint256 ethAmount = msg.value;

        // Define the path for the swap
        address tokenIn = uniswapV3Router.WETH9();
        address tokenOut = address(token);

        uint24 fee = 3000; // Choose the appropriate fee tier (e.g., 500, 3000, or 10000)

        // Calculate the minimum amount of tokens to receive
        uint256 tokensOut = 1; // Replace this with your logic for calculating the expected tokens out
        uint256 minTokens = (tokensOut * (10000 - slippageTolerance)) / 10000;

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

    // External function to swap tokens for ETH
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
        address tokenOut = uniswapV3Router.WETH9();

        uint24 fee = 3000; // Choose the appropriate fee tier (e.g., 500, 3000, or 10000)

        // Approve the Uniswap router to spend tokens
        token.approve(address(uniswapV3Router), tokenAmount);

        // Calculate the minimum amount of ETH to receive
        uint256 ethOut = 1; // Replace this with your logic for calculating the expected ETH out
        uint256 minEth = (ethOut * (10000 - slippageTolerance)) / 10000;

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
