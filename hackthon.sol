// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract EDUStaking {
    IERC20 public eduToken; // The EDU token interface
    
    // Struct to track each staker's information
    struct Staker {
        uint256 amountStaked;    // Amount of EDU tokens staked
        uint256 stakingTimestamp; // The time at which they staked
        uint256 lastClaimed;    // Last timestamp the user claimed rewards
        uint256 accumulatedRewards; // Total rewards accumulated
    }

    // Mapping from user address to staker data
    mapping(address => Staker) public stakers;

    // Reward rate variables (adjust as needed)
    uint256 public baseRewardRate = 100; // Base reward rate per token per year (e.g., 100 EDU tokens per staked EDU token per year)
    uint256 public rewardInflation = 10; // Annual inflation increase for rewards (e.g., 10% increase per year)

    // The total EDU tokens staked in the contract
    uint256 public totalStaked;

    // Events
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 reward);

    // Constructor: Set the EDU token address
    constructor(address _eduToken) {
        eduToken = IERC20(_eduToken);
    }

    // Modifier to check if the user has staked tokens
    modifier hasStaked() {
        require(stakers[msg.sender].amountStaked > 0, "You have not staked any EDU tokens");
        _;
    }

    // Stake EDU tokens into the contract
    function stake(uint256 amount) external {
        require(amount > 0, "You must stake a positive amount");

        // Transfer EDU tokens to the contract
        require(eduToken.transferFrom(msg.sender, address(this), amount), "Token transfer failed");

        Staker storage staker = stakers[msg.sender];

        // If the user has already staked tokens, claim their rewards first
        if (staker.amountStaked > 0) {
            uint256 rewards = calculateRewards(msg.sender);
            staker.accumulatedRewards += rewards;
        }

        // Update the staker's information
        staker.amountStaked += amount;
        staker.stakingTimestamp = block.timestamp;
        staker.lastClaimed = block.timestamp;

        totalStaked += amount;

        emit Staked(msg.sender, amount);
    }

    // Unstake EDU tokens from the contract
    function unstake(uint256 amount) external hasStaked {
        Staker storage staker = stakers[msg.sender];
        require(staker.amountStaked >= amount, "You do not have enough staked tokens");

        // Claim accumulated rewards before unstaking
        uint256 rewards = calculateRewards(msg.sender);
        staker.accumulatedRewards += rewards;

        // Update the staker's staked amount
        staker.amountStaked -= amount;
        totalStaked -= amount;

        // Transfer the unstaked EDU tokens back to the user
        require(eduToken.transfer(msg.sender, amount), "Token transfer failed");

        // Reset staking timestamp (to calculate rewards on future stakes)
        staker.stakingTimestamp = block.timestamp;

        emit Unstaked(msg.sender, amount);

        // Send rewards to the user
        claimRewards();
    }

    // Claim accumulated rewards for staking
    function claimRewards() public hasStaked {
        Staker storage staker = stakers[msg.sender];
        uint256 rewards = calculateRewards(msg.sender);
        staker.accumulatedRewards += rewards;

        uint256 totalRewards = staker.accumulatedRewards;

        require(totalRewards > 0, "No rewards available");

        // Reset rewards for the user
        staker.accumulatedRewards = 0;
        staker.lastClaimed = block.timestamp;

        // Transfer rewards to the user
        require(eduToken.transfer(msg.sender, totalRewards), "Reward transfer failed");

        emit RewardClaimed(msg.sender, totalRewards);
    }

    // Calculate rewards for a staker based on their staking duration and amount
    function calculateRewards(address stakerAddress) public view returns (uint256) {
        Staker storage staker = stakers[stakerAddress];
        
        // Time in seconds the tokens have been staked
        uint256 stakingDuration = block.timestamp - staker.stakingTimestamp;

        // Calculate how many seconds are in a year
        uint256 secondsInYear = 365 * 24 * 60 * 60;

        // Annual reward rate calculation
        uint256 rewardRate = baseRewardRate + (stakingDuration / secondsInYear * rewardInflation);

        // Reward formula: reward = amountStaked * rewardRate * durationInYears
        uint256 reward = (staker.amountStaked * rewardRate * stakingDuration) / secondsInYear;

        return reward;
    }

    // View function to get the total amount staked by a user
    function getStakedAmount(address user) external view returns (uint256) {
        return stakers[user].amountStaked;
    }

    // View function to get the accumulated rewards for a user
    function getAccumulatedRewards(address user) external view returns (uint256) {
        return stakers[user].accumulatedRewards + calculateRewards(user);
    }

    // View function to get the total EDU tokens staked in the contract
    function getTotalStaked() external view returns (uint256) {
        return totalStaked;
    }
}
