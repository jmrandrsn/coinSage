// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Interfaces
import "https://github.com/Uniswap/v2-periphery/blob/master/contracts/interfaces/IUniswapV2Router02.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import "https://github.com/Uniswap/v2-core/blob/master/contracts/interfaces/IUniswapV2Factory.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/security/ReentrancyGuard.sol";

// Define the contract with necessary interfaces and libraries
contract UniswapBot is ReentrancyGuard {
    // Declare variables
    IUniswapV2Router02 public uniswapV2Router;
    IUniswapV2Factory public uniswapV2Factory;
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
        address _uniswapV2RouterAddress,
        uint256 _launchTimestamp,
        uint256 _tradingWindow
    ) {
        require(_tradingWindow > 0, "Trading window must be greater than 0");

        // Initialize variables in constructor
        uniswapV2Router = IUniswapV2Router02(_uniswapV2RouterAddress);
        uniswapV2Factory = IUniswapV2Factory(uniswapV2Router.factory());
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
        require(slippageTolerance >= 0 && slippageTolerance <= 10000, "Invalid slippage tolerance");

        uint256 ethAmount = msg.value;

        // Define the path for the swap
        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = address(token);

        // Calculate the minimum amount of tokens to receive
        uint256 tokensOut = uniswapV2Router.getAmountsOut
                uint256 tokensOut = uniswapV2Router.getAmountsOut(ethAmount, path)[1];
        uint256 minTokens = (tokensOut * (10000 - slippageTolerance)) / 10000;

        // Perform the swap
        try
            uniswapV2Router.swapExactETHForTokens{value: ethAmount}(
                minTokens,
                path,
                address(this),
                block.timestamp + 300 // 5 minutes
            )
        returns (uint[] memory amounts) {
            // Handle successful swap
            uint256 tokensReceived = amounts[1];
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
        require(slippageTolerance >= 0 && slippageTolerance <= 10000, "Invalid slippage tolerance");

        // Transfer tokens from the sender to the contract
        token.transferFrom(msg.sender, address(this), tokenAmount);

        // Define the path for the swap
        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = uniswapV2Router.WETH();

        // Approve the Uniswap router to spend tokens
        token.approve(address(uniswapV2Router), tokenAmount);

        // Calculate the minimum amount of ETH to receive
        uint256 ethOut = uniswapV2Router.getAmountsOut(tokenAmount, path)[1];
        uint256 minEth = (ethOut * (10000 - slippageTolerance)) / 10000;

        // Perform the swap
        try
            uniswapV2Router.swapExactTokensForETH(
                tokenAmount,
                minEth,
                path,
                msg.sender, // Send the received ETH directly to the sender
                block.timestamp + 300 // 5 minutes
            )
        returns (uint[] memory amounts) {
            // Handle successful swap
            uint256 ethReceived = amounts[1];
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
