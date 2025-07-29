// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title CrowdfundingContract
 * @dev A decentralized crowdfunding platform smart contract
 * @author Your Name
 */
contract CrowdfundingContract {
    
    // Struct to represent a campaign
    struct Campaign {
        address payable creator;
        string title;
        string description;
        uint256 targetAmount;
        uint256 raisedAmount;
        uint256 deadline;
        bool isCompleted;
        bool fundsWithdrawn;
        mapping(address => uint256) contributions;
        address[] contributors;
    }
    
    // State variables
    mapping(uint256 => Campaign) public campaigns;
    uint256 public campaignCounter;
    uint256 public platformFeePercentage = 2; // 2% platform fee
    address payable public platformOwner;
    
    // Events
    event CampaignCreated(
        uint256 indexed campaignId,
        address indexed creator,
        string title,
        uint256 targetAmount,
        uint256 deadline
    );
    
    event ContributionMade(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );
    
    event FundsWithdrawn(
        uint256 indexed campaignId,
        address indexed creator,
        uint256 amount
    );
    
    event RefundIssued(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );
    
    // Modifiers
    modifier onlyPlatformOwner() {
        require(msg.sender == platformOwner, "Only platform owner can call this");
        _;
    }
    
    modifier campaignExists(uint256 _campaignId) {
        require(_campaignId < campaignCounter, "Campaign does not exist");
        _;
    }
    
    modifier campaignActive(uint256 _campaignId) {
        require(block.timestamp < campaigns[_campaignId].deadline, "Campaign has ended");
        require(!campaigns[_campaignId].isCompleted, "Campaign is already completed");
        _;
    }
    
    // Constructor
    constructor() {
        platformOwner = payable(msg.sender);
        campaignCounter = 0;
    }
    
    /**
     * @dev Core Function 1: Create a new crowdfunding campaign
     * @param _title Campaign title
     * @param _description Campaign description
     * @param _targetAmount Target funding amount in wei
     * @param _durationInDays Campaign duration in days
     */
    function createCampaign(
        string memory _title,
        string memory _description,
        uint256 _targetAmount,
        uint256 _durationInDays
    ) external {
        require(_targetAmount > 0, "Target amount must be greater than 0");
        require(_durationInDays > 0, "Duration must be greater than 0");
        require(bytes(_title).length > 0, "Title cannot be empty");
        
        uint256 deadline = block.timestamp + (_durationInDays * 1 days);
        
        Campaign storage newCampaign = campaigns[campaignCounter];
        newCampaign.creator = payable(msg.sender);
        newCampaign.title = _title;
        newCampaign.description = _description;
        newCampaign.targetAmount = _targetAmount;
        newCampaign.deadline = deadline;
        newCampaign.raisedAmount = 0;
        newCampaign.isCompleted = false;
        newCampaign.fundsWithdrawn = false;
        
        emit CampaignCreated(campaignCounter, msg.sender, _title, _targetAmount, deadline);
        campaignCounter++;
    }
    
    /**
     * @dev Core Function 2: Contribute to a campaign
     * @param _campaignId ID of the campaign to contribute to
     */
    function contributeToCampaign(uint256 _campaignId) 
        external 
        payable 
        campaignExists(_campaignId) 
        campaignActive(_campaignId) 
    {
        require(msg.value > 0, "Contribution must be greater than 0");
        
        Campaign storage campaign = campaigns[_campaignId];
        
        // Add contributor to the list if first contribution
        if (campaign.contributions[msg.sender] == 0) {
            campaign.contributors.push(msg.sender);
        }
        
        campaign.contributions[msg.sender] += msg.value;
        campaign.raisedAmount += msg.value;
        
        // Check if target is reached
        if (campaign.raisedAmount >= campaign.targetAmount) {
            campaign.isCompleted = true;
        }
        
        emit ContributionMade(_campaignId, msg.sender, msg.value);
    }
    
    /**
     * @dev Core Function 3: Withdraw funds or get refund
     * @param _campaignId ID of the campaign
     */
    function withdrawFunds(uint256 _campaignId) 
        external 
        campaignExists(_campaignId) 
    {
        Campaign storage campaign = campaigns[_campaignId];
        
        // Case 1: Campaign creator withdrawing successful campaign funds
        if (msg.sender == campaign.creator) {
            require(campaign.isCompleted || block.timestamp >= campaign.deadline, 
                    "Campaign not completed or deadline not reached");
            require(!campaign.fundsWithdrawn, "Funds already withdrawn");
            require(campaign.raisedAmount > 0, "No funds to withdraw");
            
            uint256 platformFee = (campaign.raisedAmount * platformFeePercentage) / 100;
            uint256 creatorAmount = campaign.raisedAmount - platformFee;
            
            campaign.fundsWithdrawn = true;
            
            // Transfer funds
            platformOwner.transfer(platformFee);
            campaign.creator.transfer(creatorAmount);
            
            emit FundsWithdrawn(_campaignId, campaign.creator, creatorAmount);
        }
        // Case 2: Contributor requesting refund for failed campaign
        else {
            require(block.timestamp >= campaign.deadline, "Campaign still active");
            require(!campaign.isCompleted, "Campaign was successful, no refunds");
            require(campaign.contributions[msg.sender] > 0, "No contribution found");
            
            uint256 refundAmount = campaign.contributions[msg.sender];
            campaign.contributions[msg.sender] = 0;
            campaign.raisedAmount -= refundAmount;
            
            payable(msg.sender).transfer(refundAmount);
            
            emit RefundIssued(_campaignId, msg.sender, refundAmount);
        }
    }
    
    // View functions
    function getCampaignDetails(uint256 _campaignId) 
        external 
        view 
        campaignExists(_campaignId) 
        returns (
            address creator,
            string memory title,
            string memory description,
            uint256 targetAmount,
            uint256 raisedAmount,
            uint256 deadline,
            bool isCompleted,
            bool fundsWithdrawn
        ) 
    {
        Campaign storage campaign = campaigns[_campaignId];
        return (
            campaign.creator,
            campaign.title,
            campaign.description,
            campaign.targetAmount,
            campaign.raisedAmount,
            campaign.deadline,
            campaign.isCompleted,
            campaign.fundsWithdrawn
        );
    }
    
    function getContribution(uint256 _campaignId, address _contributor) 
        external 
        view 
        campaignExists(_campaignId) 
        returns (uint256) 
    {
        return campaigns[_campaignId].contributions[_contributor];
    }
    
    function getCampaignContributors(uint256 _campaignId) 
        external 
        view 
        campaignExists(_campaignId) 
        returns (address[] memory) 
    {
        return campaigns[_campaignId].contributors;
    }
    
    // Admin functions
    function updatePlatformFee(uint256 _newFeePercentage) external onlyPlatformOwner {
        require(_newFeePercentage <= 10, "Fee cannot exceed 10%");
        platformFeePercentage = _newFeePercentage;
    }
    
    function transferOwnership(address payable _newOwner) external onlyPlatformOwner {
        require(_newOwner != address(0), "Invalid address");
        platformOwner = _newOwner;
    }
}
