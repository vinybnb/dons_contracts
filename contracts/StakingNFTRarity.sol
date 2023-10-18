// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract StakingNFTRarity is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    Counters.Counter internal _tokenIdCounter;
    mapping(uint256 => uint256) public tierToDailyAPR; /// tokens per day
    uint256[] public tiers;

    constructor() {
        tierToDailyAPR[1] = 172 * 1e18;
        tierToDailyAPR[2] = 103 * 1e18;
        tierToDailyAPR[3] = 69 * 1e18;

        tokenContract = IERC20(0x6584f00fb92218A6A92978a91b6185555a432519);
        nftContract = IERC721(0x3CBc6322495D1871Dd6f178c06bcfa6d82662CF3);
    }

    event Staked(
        address indexed staker,
        uint256 indexed stakeId,
        uint256 nftId
    );

    event RequestClaimed(address indexed staker, uint256 indexed stakeId);

    event Claimed(
        address indexed staker,
        uint256 indexed stakeId,
        uint256 amount,
        uint256 nftId
    );

    IERC721 public nftContract;
    IERC20 public tokenContract;

    address[] internal _addresses;

    mapping(address => uint256[]) private addressToIds;

    mapping(uint256 => StakeDetail) public idToStakeDetail;

    uint256 constant ONE_DAY_IN_SECONDS = 24 * 60 * 60;
    uint256 constant ONE_HOUR_IN_SECONDS = 60 * 60;

    bool public enabled = true;

    struct StakeDetail {
        address staker;
        uint256 startAt;
        uint256 stakedNFTId;
        uint256 claimedAmount;
        StakeStatus status;
    }

    enum StakeStatus {
        Staked,
        Withdrawn
    }

    function setDailyAPRPerNFT(uint256 _tier, uint256 _dailyAPR) external onlyOwner {
        tierToDailyAPR[_tier] = _dailyAPR;
    } 

    function setEnabled(bool _enabled) external onlyOwner {
        enabled = _enabled;
    }

    function setNftContractAddress(address _nftAddress) external onlyOwner {
        nftContract = IERC721(_nftAddress);
    }

    function resetTiers() external onlyOwner {
        delete tiers;
    }

    function addTiers(uint256[] memory _tiers) external onlyOwner {
        for (uint256 i = 0; i < _tiers.length; i++) {
            tiers.push(_tiers[i]);
        }
    }

    function setTokenContractAddress(
        address _newTokenAddress
    ) external onlyOwner {
        tokenContract = IERC20(_newTokenAddress);
    }

    function getStakeDetail(
        uint256 _id
    ) external view returns (StakeDetail memory) {
        return idToStakeDetail[_id];
    }

    function getDailyAPRById(
        uint256 _id
    ) external view returns (uint256) {
        return tierToDailyAPR[tiers[_id-1]];
    }

    function stake(uint256 _nftId) external nonReentrant {
        uint256 currentTimestamp = block.timestamp;
        require(enabled, "Staking is disabled");
        require(
            nftContract.ownerOf(_nftId) == msg.sender,
            "You are not the owner of this nft"
        );
        nftContract.transferFrom(msg.sender, address(this), _nftId);
        uint256 currentId = _tokenIdCounter.current();
        StakeDetail memory newStakeDetail = StakeDetail(
            msg.sender,
            currentTimestamp,
            _nftId,
            0,
            StakeStatus.Staked
        );
        idToStakeDetail[currentId] = newStakeDetail;

        addressToIds[msg.sender].push(currentId);
        _tokenIdCounter.increment();
        emit Staked(msg.sender, currentId, _nftId);
    }

    function claim(uint256 _stakeId) external nonReentrant {
        StakeDetail storage stakeDetail = idToStakeDetail[_stakeId];
        uint256 currentInterest = getCurrentInterestById(_stakeId);
        require(
            stakeDetail.status == StakeStatus.Staked,
            "Stake is already withdrawn"
        );
        require(
            stakeDetail.staker == msg.sender,
            "You are not the staker of this stake"
        );
        if (currentInterest > 0) {
            tokenContract.transfer(msg.sender, currentInterest);
            stakeDetail.claimedAmount = stakeDetail.claimedAmount.add(
                currentInterest
            );
        }
    }

    function withdraw(uint256 _stakeId) external nonReentrant {
        StakeDetail storage stakeDetail = idToStakeDetail[_stakeId];
        require(
            stakeDetail.status == StakeStatus.Staked,
            "Stake is already claimed"
        );
        require(
            stakeDetail.staker == msg.sender,
            "You are not the staker of this stake"
        );
        nftContract.transferFrom(
            address(this),
            msg.sender,
            stakeDetail.stakedNFTId
        );
        uint256 currentInterest = getCurrentInterestById(_stakeId);
        if (currentInterest > 0) {
            tokenContract.transfer(msg.sender, currentInterest);
            stakeDetail.claimedAmount = stakeDetail.claimedAmount.add(
                currentInterest
            );
        }
        stakeDetail.status = StakeStatus.Withdrawn;
    }

    function getCurrentInterestById(
        uint256 _id
    ) public view returns (uint256 interest) {
        require(_id >= 1, "Invalid id");
        StakeDetail memory stakeDetail = idToStakeDetail[_id];
        uint256 currentTimestamp = block.timestamp;
        uint256 stakedTimestamp = stakeDetail.startAt;
        uint256 totalDays = (currentTimestamp.sub(stakedTimestamp)).div(
            ONE_DAY_IN_SECONDS
        );
        interest = totalDays.mul(tierToDailyAPR[tiers[_id-1]]).sub(stakeDetail.claimedAmount);
        return interest;
    }

    function getCurrentTotalInterestOfAddress(
        address _address
    ) public view returns (uint256) {
        uint256 currentInterest = 0;
        for (uint256 i = 0; i < addressToIds[_address].length; i++) {
            currentInterest = currentInterest.add(
                getCurrentInterestById(addressToIds[_address][i])
            );
        }
        return currentInterest;
    }

    function getStakingIds(
        address _address
    ) external view returns (uint256[] memory) {
        return addressToIds[_address];
    }

    function getStakeHoldersCount() external view returns (uint256) {
        return _addresses.length;
    }

    function getAddressByIndex(uint256 _index) external view returns (address) {
        return _addresses[_index];
    }

    function transfer(
        address _recipient,
        uint256 _amount
    ) external onlyOwner returns (bool) {
        return tokenContract.transfer(_recipient, _amount);
    }
}