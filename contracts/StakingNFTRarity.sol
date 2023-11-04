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
    uint8[] public tiers;
    uint256 public collectionSize;

    uint256 public stakeHolderCount;
    mapping(address => bool) public isStakeHolder;

    struct NFTDetail {
        uint256 tokenId;
        uint8 tier;
    }

    constructor(
        uint256 _collectionSize,
        address _tokenContract,
        address _nftContract
    ) {
        tierToDailyAPR[1] = 172 * 1e18;
        tierToDailyAPR[2] = 103 * 1e18;
        tierToDailyAPR[3] = 69 * 1e18;

        collectionSize = _collectionSize;

        tokenContract = IERC20(_tokenContract);
        nftContract = IERC721(_nftContract);
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

    mapping(address => uint256[]) private addressToIds;

    mapping(uint256 => StakeDetail) public idToStakeDetail;

    uint256 ONE_DAY_IN_SECONDS = 24 * 60 * 60;
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

    function setDailyAPRPerNFT(
        uint256 _tier,
        uint256 _dailyAPR
    ) external onlyOwner {
        tierToDailyAPR[_tier] = _dailyAPR;
    }

    function setCollectionSize(uint256 _collectionSize) external onlyOwner {
        collectionSize = _collectionSize;
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

    function addTiers(uint8[] memory _tiers) external onlyOwner {
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

    function stake(uint256[] memory _nftIds) external nonReentrant {
        uint256 currentTimestamp = block.timestamp;
        for (uint256 i; i < _nftIds.length; i++) {
            uint256 _nftId = _nftIds[i];
            require(_nftId > 0, "Invalid NFT id");
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
            uint256 stakingIds = countStakingIds(msg.sender);
            if (stakingIds == 0) {
                stakeHolderCount++;
                isStakeHolder[msg.sender] = true;
            }
            addressToIds[msg.sender].push(currentId);
            _tokenIdCounter.increment();
            emit Staked(msg.sender, currentId, _nftId);
        }
    }

    function countStakingIds(address _owner) public view returns (uint256) {
        uint256[] storage stakeIds = addressToIds[_owner];
        uint256 stakingIds = 0;
        for (uint256 i = 0; i < stakeIds.length; i++) {
            if (idToStakeDetail[stakeIds[i]].status == StakeStatus.Staked) {
                stakingIds++;
            }
        }
        return stakingIds;
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

    function claimAll() external nonReentrant {
        uint256[] storage stakeIds = addressToIds[msg.sender];
        uint256 accumulatedInterest = 0;
        for (uint256 i; i < stakeIds.length; i++) {
            uint256 stakeId = stakeIds[i];
            StakeDetail storage stakeDetail = idToStakeDetail[stakeId];
            uint256 currentInterest = getCurrentInterestById(stakeId);
            require(
                stakeDetail.staker == msg.sender,
                "You are not the staker of this stake"
            );
            if (currentInterest > 0) {
                accumulatedInterest = accumulatedInterest.add(currentInterest);
                stakeDetail.claimedAmount = stakeDetail.claimedAmount.add(
                    currentInterest
                );
            }
        }
        tokenContract.transfer(msg.sender, accumulatedInterest);
    }

    function withdraw(uint256[]  memory _stakeIds) external nonReentrant {
        for(uint256 i; i < _stakeIds.length; i++) {
            uint256 _stakeId = _stakeIds[i];
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
            uint256 remainingStakeIds = countStakingIds(msg.sender);
            if (remainingStakeIds == 0) {
                stakeHolderCount--;
                isStakeHolder[msg.sender] = false;
            }
        }
    }

    function getCurrentInterestById(
        uint256 _id
    ) public view returns (uint256 interest) {
        StakeDetail memory stakeDetail = idToStakeDetail[_id];
        if (stakeDetail.status == StakeStatus.Withdrawn) {
            return 0;
        }
        uint256 currentTimestamp = block.timestamp;
        uint256 stakedTimestamp = stakeDetail.startAt;
        if (currentTimestamp <= stakedTimestamp) {
            return 0;
        }
        uint256 tokensPerSeconds = tierToDailyAPR[
            uint256(tiers[stakeDetail.stakedNFTId - 1])
        ] / ONE_DAY_IN_SECONDS;
        uint256 totalSeconds = currentTimestamp.sub(stakedTimestamp);
        interest = totalSeconds.mul(tokensPerSeconds).sub(
            stakeDetail.claimedAmount
        );
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

    function transfer(
        address _recipient,
        uint256 _amount
    ) external onlyOwner returns (bool) {
        return tokenContract.transfer(_recipient, _amount);
    }

    function getNFTsOfOwner(
        address _addr
    ) external view returns (NFTDetail[] memory) {
        bool[] memory temp = new bool[](collectionSize);
        uint256 count = 0;

        unchecked {
            for (uint i = 1; i <= collectionSize; i++) {
                try nftContract.ownerOf(i) returns (address owner) {
                    if (owner == _addr) {
                        count++;
                        temp[i - 1] = true;
                    }
                } catch {
                    break;
                }
            }

            NFTDetail[] memory tokenIds = new NFTDetail[](count);
            count = 0;
            for (uint i = 1; i <= collectionSize; i++) {
                if (temp[i - 1]) {
                    tokenIds[count++].tokenId = i;
                    tokenIds[count - 1].tier = tiers[i - 1];
                }
            }
            return tokenIds;
        }
    }
}
