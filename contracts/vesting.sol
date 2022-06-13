// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract LinearVesting is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 constant AdvisorPercent = 5;
    uint256 constant PartnersPercent = 0;
    uint256 constant MentorsPercent = 7;
    uint256 constant deno = 100;

    uint256 private immutable _cliff;
    uint256 private immutable _duration;
    IERC20 private immutable token;
    bool public isVestingStarted;

    uint256 private totalAdvisors;
    uint256 private totalPartners;
    uint256 private totalMentors;

    uint256 startTime;

    enum Roles {
        advisor,
        partnership,
        mentor
    }

    Roles private role;

    struct Beneficiary {
        uint8 role;
        bool isBeneficiary;
        uint256 tokenClaim;
        uint256 lastClaim;
    }

    mapping(uint256 => uint256) public totalTokensForRole;
    mapping(address => Beneficiary) beneficiaryMap;
    event VestingStarted(uint256 cliff, uint256 duration);
    event AddedBeneficiary(address beneficiary, uint256 role);

    constructor(
        address tokenAdd,
        uint256 cliff,
        uint256 duration
    ) public {
        require(
            tokenAdd != address(0),
            "Vesting: token address can't be zero address"
        );
        require(duration > 0, "Vesting: Duration can't be zero");
        require(
            cliff <= duration,
            "Vesting: cliff can't be longer than duration"
        );
        token = IERC20(tokenAdd);
        _cliff = cliff;
        _duration = duration;
    }

    function addBeneficiaryRole(address _beneficiary, uint8 benRole)
        external
        onlyOwner
    {
        require(
            !isVestingStarted,
            "vesting.sol: vesting has started, couldn't add beneficiary"
        );
        require(
            beneficiaryMap[_beneficiary].isBeneficiary == false,
            "Beneficiary is active"
        );
        require(benRole < 3 && benRole >= 0, "Role should be between 0 to 2");
        beneficiaryMap[_beneficiary].isBeneficiary = true;
        beneficiaryMap[_beneficiary].role = benRole;

        emit AddedBeneficiary(_beneficiary, benRole);
    }

    function startVesting() external onlyOwner {
        require(!isVestingStarted, "vesting.sol: vesting already started");
        uint256 totalTokens = token.balanceOf(address(this));
        isVestingStarted = true;
        startTime = block.timestamp;
        calculateTokens(totalTokens);

        emit VestingStarted(_cliff, _duration);
    }

    function claimToken() external nonReentrant {
        require(isVestingStarted == true, "Vesting has not started yet!");
        require(
            beneficiaryMap[msg.sender].isBeneficiary == true,
            "You are not beneficiary"
        );
        require(
            block.timestamp >= _cliff + startTime,
            "Can't Claim tokens as vesting is in cliff period"
        );
        require(
            block.timestamp - beneficiaryMap[msg.sender].lastClaim > 2629743,
            "already claim within last month"
        );

        uint8 senderRole = beneficiaryMap[msg.sender].role;
        uint256 tokensClaimed = beneficiaryMap[msg.sender].tokenClaim;

        require(
            tokensClaimed < totalTokensForRole[senderRole],
            "Vesting.sol: Claimed enough Tokens"
        );
        uint256 tokens = getTokensTillDate(senderRole, tokensClaimed);

        beneficiaryMap[msg.sender].lastClaim = block.timestamp;
        beneficiaryMap[msg.sender].tokenClaim += tokens;
        token.safeTransfer(msg.sender, tokens);
    }

    function calculateTokens(uint256 totalTokens) private {
        totalTokensForRole[0] = (totalTokens * AdvisorPercent) / deno;
        totalTokensForRole[1] = (totalTokens * PartnersPercent) / deno;
        totalTokensForRole[2] = (totalTokens * MentorsPercent) / deno;
    }

    function getTokensVested(uint256 senderRole)
        private view
        returns (uint256 vestedAmount)
    {
        require(
            isVestingStarted == true,
            "Vesting: Vesting has not started yet!"
        );
        require(senderRole < 3 && senderRole >= 0, "Vesting: Role in between 0 to 2");
        uint256 tokensForRole = totalTokensForRole[senderRole];
        if (block.timestamp <= _cliff) {
            return 0;
        } else if (block.timestamp >= (_cliff + _duration)) {
            return tokensForRole;
        } else {
            return (tokensForRole * (block.timestamp - _cliff)) / _duration;
        }
    }

    function getTokensTillDate(uint256 senderRole, uint256 tokensClaimed)
        private
        view
        returns (uint256)
    {
        uint256 timeAfterCliff = block.timestamp - _cliff - startTime;
        uint256 tokens;
        if (timeAfterCliff > _duration) {
            return totalTokensForRole[senderRole];
        } else {
            tokens =
                (totalTokensForRole[senderRole] * timeAfterCliff) /
                _duration;
        }
        return tokens - tokensClaimed;
    }
}
