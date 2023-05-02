// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BrownHouseToken is ERC20, ReentrancyGuard, Ownable {
    using SafeMath for uint;

    uint256 public constant SALE_START_TIMESTAMP = 1683031043; // Set your token sale start timestamp
    uint256 public constant SALE_END_TIMESTAMP = SALE_START_TIMESTAMP + 7 days; // Set your token sale duration

    uint256 public exchange_rate = 100; // Example exchange rate, 1 Ether = 100 BrownHouse tokens
    uint256 public max_purchase_limit = 5000 * 10 ** 18; // Example max purchase limit per address

    mapping(address => uint256) public purchasedAmount;
    mapping(address => bool) public whitelistedAddresses;

    event WhitelistUpdated(address indexed account, bool isWhitelisted);

    constructor() ERC20("BrownHouse Token", "BHT") {
        uint256 _totalSupply = 1000000 * 10 ** 18; // Hardcoded total supply
        _mint(msg.sender, _totalSupply);
    }

    modifier onlyDuringSale() {
        require(
            block.timestamp >= SALE_START_TIMESTAMP &&
                block.timestamp <= SALE_END_TIMESTAMP,
            "Sale not active"
        );
        _;
    }

    modifier onlyWhitelisted() {
        require(whitelistedAddresses[msg.sender], "Not whitelisted");
        _;
    }

    function setExchangeRate(uint256 _exchange_rate) external onlyOwner {
        exchange_rate = _exchange_rate;
    }

    function setMaxPurchaseLimit(
        uint256 _max_purchase_limit
    ) external onlyOwner {
        max_purchase_limit = _max_purchase_limit;
    }

    function updateWhitelist(
        address _account,
        bool _isWhitelisted
    ) external onlyOwner {
        whitelistedAddresses[_account] = _isWhitelisted;
        emit WhitelistUpdated(_account, _isWhitelisted);
    }

    function purchase()
        external
        payable
        onlyDuringSale
        onlyWhitelisted
        nonReentrant
    {
        require(msg.value > 0, "Must send Ether");
        uint256 amount = msg.value.mul(exchange_rate);
        uint256 newPurchasedAmount = purchasedAmount[msg.sender].add(amount);
        require(
            newPurchasedAmount <= max_purchase_limit,
            "Exceeds max purchase limit"
        );

        purchasedAmount[msg.sender] = newPurchasedAmount;
        _transfer(owner(), msg.sender, amount);
        payable(owner()).transfer(msg.value);
    }

    // Function to withdraw any unsold tokens after the sale ends
    function withdrawUnsoldTokens() external onlyOwner {
        require(block.timestamp > SALE_END_TIMESTAMP, "Sale not ended yet");
        _transfer(owner(), msg.sender, balanceOf(owner()));
    }

    // Function to withdraw any Ether left in the contract after the sale ends
    function withdrawRemainingEther() external onlyOwner {
        require(block.timestamp > SALE_END_TIMESTAMP, "Sale not ended yet");
        payable(msg.sender).transfer(address(this).balance);
    }
}
