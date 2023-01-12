// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "erc721a/contracts/IERC721A.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract PatrickiezStaking is ReentrancyGuard {

    using SafeERC20 for IERC20;
    using Address for address payable;

    IERC20 public immutable rewardsToken;
    IERC721A public immutable nftCollection;

    uint16 private rewardsPerMinute = 1000;

    mapping(address => Staker) public stakers;
    mapping(uint256 => address) public stakerAddress;

    struct StakedToken {
        address staker;
        uint256 tokenId;
    }

    struct Staker {
        uint256 amountStaked;
        uint256 timeOfLastUpdate;
        uint256 unclaimedRewards;
        StakedToken[] tokens;
    }

    constructor(IERC721A _nftCollection, IERC20 _rewardsToken){
        rewardsToken = _rewardsToken;
        nftCollection = _nftCollection;
    }
    
    receive() external payable {
        payable(msg.sender).sendValue(msg.value);
    }

  
    function stake(uint256 _tokenId) external nonReentrant {
        require(nftCollection.ownerOf(_tokenId) == msg.sender, "You do not own that token!");

        stakers[msg.sender].amountStaked++;

        stakers[msg.sender].unclaimedRewards += calculateRewards(msg.sender);

        stakers[msg.sender].timeOfLastUpdate = block.timestamp;

        stakerAddress[_tokenId] = msg.sender;
        
        StakedToken memory _toPush = StakedToken(msg.sender, _tokenId);

        stakers[msg.sender].tokens.push(_toPush);

        nftCollection.safeTransferFrom(msg.sender, address(this), _tokenId);

    }


    function unstake(uint256 _tokenId) external nonReentrant {
        require(stakers[msg.sender].amountStaked > 0, "You have no tokens staked!");
        require(stakerAddress[_tokenId] != address(0), "Token is not staked or doesn't exist");
        require(stakerAddress[_tokenId] == msg.sender, "That is not your token to unstake");

        stakers[msg.sender].amountStaked--;

        stakers[msg.sender].unclaimedRewards += calculateRewards(msg.sender);

        stakers[msg.sender].timeOfLastUpdate = block.timestamp;

        stakerAddress[_tokenId] = address(0);

        uint256 index;

        for(uint i = 0; i< stakers[msg.sender].tokens.length; i++){
            if(stakers[msg.sender].tokens[i].tokenId == _tokenId
                &&
                stakers[msg.sender].tokens[i].staker != address(0))
            {
                index = i;
                break;
            }
        }

        stakers[msg.sender].tokens[index].staker = address(0);

        nftCollection.transferFrom(address(this), msg.sender, _tokenId);

    }

    function claimRewards() external {
        uint256 _rewards = stakers[msg.sender].unclaimedRewards += calculateRewards(msg.sender);
        require(_rewards > 0, "You don't have anything to claim");
        stakers[msg.sender].unclaimedRewards = 0;
        stakers[msg.sender].timeOfLastUpdate = block.timestamp;
        rewardsToken.safeTransfer(msg.sender, _rewards);
    }

    //multiply current rate by (duration staked*number of NFTs)
    //Rate = 1000 per minute per NFT
    function calculateRewards(address _staker) internal view returns(uint256) {
        uint256 _duration = block.timestamp - stakers[_staker].timeOfLastUpdate;
        uint256 _amount = stakers[_staker].amountStaked;
        return(((_duration*_amount)*rewardsPerMinute)/60);
    }

    function getStakedTokens(address _staker) external view returns(StakedToken[] memory){
        if(stakers[_staker].amountStaked > 0){
            uint256 _len = stakers[_staker].amountStaked;
            StakedToken[] memory _stakedTokens = new StakedToken[](_len);

            for(uint i = 0; i < _len; i++){
                if(stakers[_staker].tokens[i].staker != address(0)){
                    _stakedTokens[i] = stakers[_staker].tokens[i];
                }
            }

            return _stakedTokens;


        } else {
            return new StakedToken[](0);
        }
    }

    function availableRewards(address _staker) public view returns(uint256){
        return stakers[_staker].unclaimedRewards + calculateRewards(_staker);
    }

}
