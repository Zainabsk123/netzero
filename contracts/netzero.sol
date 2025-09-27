// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title NetZero
 * @dev A smart contract for carbon offset trading and environmental impact tracking
 * @author NetZero Team
 */
contract Project {
    // State variables
    address public owner;
    uint256 public totalCarbonCredits;
    uint256 public totalUsersRegistered;
    
    // Structs
    struct User {
        address userAddress;
        uint256 carbonFootprint; // in kg CO2
        uint256 carbonCreditsOwned;
        uint256 rewardTokens;
        bool isRegistered;
        uint256 registrationTimestamp;
    }
    
    struct CarbonCredit {
        uint256 creditId;
        address seller;
        uint256 amount; // in kg CO2 equivalent
        uint256 pricePerCredit; // in wei
        bool isActive;
        string projectDescription;
        uint256 creationTimestamp;
    }
    
    // Mappings
    mapping(address => User) public users;
    mapping(uint256 => CarbonCredit) public carbonCredits;
    
    // Events
    event UserRegistered(address indexed userAddress, uint256 timestamp);
    event CarbonCreditListed(uint256 indexed creditId, address indexed seller, uint256 amount, uint256 price);
    event CarbonCreditPurchased(uint256 indexed creditId, address indexed buyer, address indexed seller, uint256 amount);
    event ImpactUpdated(address indexed userAddress, uint256 oldFootprint, uint256 newFootprint);
    event RewardDistributed(address indexed userAddress, uint256 rewardAmount);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier onlyRegisteredUser() {
        require(users[msg.sender].isRegistered, "User must be registered");
        _;
    }
    
    // Constructor
    constructor() {
        owner = msg.sender;
        totalCarbonCredits = 0;
        totalUsersRegistered = 0;
    }
    
    /**
     * @dev Core Function 1: Register a new user in the NetZero platform
     * @param _initialFootprint Initial carbon footprint in kg CO2
     */
    function registerUser(uint256 _initialFootprint) external {
        require(!users[msg.sender].isRegistered, "User already registered");
        require(_initialFootprint >= 0, "Carbon footprint cannot be negative");
        
        users[msg.sender] = User({
            userAddress: msg.sender,
            carbonFootprint: _initialFootprint,
            carbonCreditsOwned: 0,
            rewardTokens: 0,
            isRegistered: true,
            registrationTimestamp: block.timestamp
        });
        
        totalUsersRegistered++;
        
        emit UserRegistered(msg.sender, block.timestamp);
    }
    
    /**
     * @dev Core Function 2: Purchase carbon credits from the marketplace
     * @param _creditId ID of the carbon credit to purchase
     * @param _amount Amount of credits to purchase (in kg CO2 equivalent)
     */
    function purchaseCarbonCredits(uint256 _creditId, uint256 _amount) external payable onlyRegisteredUser {
        require(_creditId < totalCarbonCredits, "Invalid credit ID");
        require(_amount > 0, "Amount must be greater than 0");
        
        CarbonCredit storage credit = carbonCredits[_creditId];
        require(credit.isActive, "Carbon credit is not active");
        require(credit.amount >= _amount, "Insufficient credits available");
        
        uint256 totalCost = _amount * credit.pricePerCredit;
        require(msg.value >= totalCost, "Insufficient payment");
        
        // Update credit availability
        credit.amount -= _amount;
        if (credit.amount == 0) {
            credit.isActive = false;
        }
        
        // Update buyer's carbon credits
        users[msg.sender].carbonCreditsOwned += _amount;
        
        // Transfer payment to seller
        payable(credit.seller).transfer(totalCost);
        
        // Refund excess payment if any
        if (msg.value > totalCost) {
            payable(msg.sender).transfer(msg.value - totalCost);
        }
        
        // Distribute reward tokens (10% of credits purchased)
        uint256 rewardAmount = _amount / 10;
        users[msg.sender].rewardTokens += rewardAmount;
        
        emit CarbonCreditPurchased(_creditId, msg.sender, credit.seller, _amount);
        emit RewardDistributed(msg.sender, rewardAmount);
    }
    
    /**
     * @dev Core Function 3: Update user's environmental impact and distribute rewards
     * @param _newFootprint Updated carbon footprint in kg CO2
     */
    function updateEnvironmentalImpact(uint256 _newFootprint) external onlyRegisteredUser {
        require(_newFootprint >= 0, "Carbon footprint cannot be negative");
        
        User storage user = users[msg.sender];
        uint256 oldFootprint = user.carbonFootprint;
        
        user.carbonFootprint = _newFootprint;
        
        // Reward users for reducing their carbon footprint
        if (_newFootprint < oldFootprint) {
            uint256 reduction = oldFootprint - _newFootprint;
            uint256 rewardTokens = reduction / 100; // 1 reward token per 100kg CO2 reduction
            
            user.rewardTokens += rewardTokens;
            emit RewardDistributed(msg.sender, rewardTokens);
        }
        
        emit ImpactUpdated(msg.sender, oldFootprint, _newFootprint);
    }
    
    // Additional utility functions
    
    /**
     * @dev List carbon credits for sale (only owner can verify and list)
     * @param _seller Address of the credit seller
     * @param _amount Amount of credits in kg CO2 equivalent
     * @param _pricePerCredit Price per credit in wei
     * @param _description Description of the offset project
     */
    function listCarbonCredits(
        address _seller,
        uint256 _amount,
        uint256 _pricePerCredit,
        string memory _description
    ) external onlyOwner {
        require(_amount > 0, "Amount must be greater than 0");
        require(_pricePerCredit > 0, "Price must be greater than 0");
        require(users[_seller].isRegistered, "Seller must be registered");
        
        carbonCredits[totalCarbonCredits] = CarbonCredit({
            creditId: totalCarbonCredits,
            seller: _seller,
            amount: _amount,
            pricePerCredit: _pricePerCredit,
            isActive: true,
            projectDescription: _description,
            creationTimestamp: block.timestamp
        });
        
        emit CarbonCreditListed(totalCarbonCredits, _seller, _amount, _pricePerCredit);
        totalCarbonCredits++;
    }
    
    /**
     * @dev Get user information
     * @param _userAddress Address of the user
     * @return User struct information
     */
    function getUserInfo(address _userAddress) external view returns (User memory) {
        require(users[_userAddress].isRegistered, "User not registered");
        return users[_userAddress];
    }
    
    /**
     * @dev Get carbon credit information
     * @param _creditId ID of the carbon credit
     * @return CarbonCredit struct information
     */
    function getCarbonCreditInfo(uint256 _creditId) external view returns (CarbonCredit memory) {
        require(_creditId < totalCarbonCredits, "Invalid credit ID");
        return carbonCredits[_creditId];
    }
    
    /**
     * @dev Get total platform statistics
     * @return totalCredits Total carbon credits listed
     * @return totalUsers Total registered users
     */
    function getPlatformStats() external view returns (uint256 totalCredits, uint256 totalUsers) {
        return (totalCarbonCredits, totalUsersRegistered);
    }
    
    /**
     * @dev Emergency function to pause/unpause credit operations (only owner)
     * @param _creditId ID of the carbon credit
     * @param _isActive New active status
     */
    function updateCreditStatus(uint256 _creditId, bool _isActive) external onlyOwner {
        require(_creditId < totalCarbonCredits, "Invalid credit ID");
        carbonCredits[_creditId].isActive = _isActive;
    }
}
