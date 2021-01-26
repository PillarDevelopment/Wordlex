// SPDX-License-Identifier: MIT
pragma solidity ^0.5.8;

import  "./ITRC20.sol";
import "./IWordLexStatus.sol";
import "./Ownable.sol";
import "./SafeMath.sol";

contract WordLexStaking is Ownable{
    using SafeMath for uint256;
    using SafeMath for uint40;

    struct User {
        address upline;
        uint256 referrals;
        uint256 payouts;
        uint256 matchBonus;
        uint256 depositAmount;
        uint256 depositPayouts;
        uint40 depositTime;
        uint256 withdrawTime;
        uint256 totalDeposits;
        uint256 totalPayouts;
        uint256 totalStructure;
    }

    ITRC20 public WDX;
    IWordLexStatus public statusContract;

    mapping(address => User) public users;
    uint8[] public ref_bonuses;

    uint256 public total_users = 1;
    uint256 public total_deposited;
    uint256 public total_withdraw;
    uint256 public minimumDailyPercent = 6;

    event Upline(address indexed addr, address indexed upline);
    event NewDeposit(address indexed addr, uint256 amount);
    event MatchPayout(address indexed addr, address indexed from, uint256 amount);
    event Withdraw(address indexed addr, uint256 amount);
    event LimitReached(address indexed addr, uint256 amount);

    constructor(ITRC20 _wdx, IWordLexStatus _statusContract) public {
        WDX = _wdx;
        statusContract = _statusContract;

        ref_bonuses.push(20);
        ref_bonuses.push(20);
        ref_bonuses.push(20);
        ref_bonuses.push(20);
        ref_bonuses.push(20);
        ref_bonuses.push(20);
        ref_bonuses.push(20);
        ref_bonuses.push(20);
        ref_bonuses.push(20);
        ref_bonuses.push(20);
    }


    /**
     ###################################################################################
     ##############################    Public          #################################
     ###################################################################################
     */
    function deposit(address _upline, uint256 _amount)  public {
        _setUpline(msg.sender, _upline);
        _deposit(msg.sender, _amount);
        WDX.transferFrom(msg.sender, address(this), _amount);
    }


    function withdraw() public {
        (uint256 to_payout, uint256 max_payout) = this.payoutOf(msg.sender);
        require(users[msg.sender].withdrawTime.add(7 days) < block.timestamp,
                "WordLexStaking: Less than 7 days have passed since the last withdrawal");

        if(to_payout > 0) {
            if(users[msg.sender].payouts.add(to_payout)  > max_payout) {
                to_payout = max_payout.sub(users[msg.sender].payouts);
            }
            users[msg.sender].depositPayouts += to_payout;
            users[msg.sender].payouts += to_payout;
            _refPayout(msg.sender, to_payout);
        }

        if(users[msg.sender].payouts < max_payout && users[msg.sender].matchBonus > 0) {
            uint256 matchBonus = users[msg.sender].matchBonus;

            if(users[msg.sender].payouts.add(matchBonus) > max_payout) {
                matchBonus = max_payout.sub(users[msg.sender].payouts);
            }

            users[msg.sender].matchBonus -= matchBonus;
            users[msg.sender].payouts += matchBonus;
            to_payout += matchBonus;
        }
        require(to_payout > 0, "WordLexStaking: Zero payout");

        users[msg.sender].totalPayouts += to_payout;
        total_withdraw += to_payout;
        users[msg.sender].withdrawTime = block.timestamp;
        WDX.transfer(msg.sender, to_payout);

        emit Withdraw(msg.sender, to_payout);
        if(users[msg.sender].payouts >= max_payout) {
            emit LimitReached(msg.sender, users[msg.sender].payouts);
        }
    }


    /**
    ###################################################################################
    ##############################     Internal       #################################
    ###################################################################################
    */
    function _setUpline(address _addr, address _upline) internal {
        if(users[_addr].upline == address(0) && _upline != _addr
            && _addr != owner() && (users[_upline].depositTime > 0 || _upline == owner())) {
            users[_addr].upline = _upline;
            users[_upline].referrals++;

            emit Upline(_addr, _upline);
            total_users++;

            for(uint8 i = 0; i < ref_bonuses.length; i++) {
                if(_upline == address(0)) break;
                users[_upline].totalStructure++;
                _upline = users[_upline].upline;
            }
        }
    }


    function _deposit(address _addr, uint256 _amount) internal {
        require(users[_addr].upline != address(0) || _addr == owner(), "WordLexStaking: No upLine");

        users[_addr].payouts = 0;
        users[_addr].depositAmount = users[_addr].depositAmount.add(_amount);
        users[_addr].depositPayouts = 0;
        if (users[_addr].depositTime == 0) {
            users[_addr].depositTime = uint40(block.timestamp);
        }
        users[_addr].totalDeposits += _amount;

        total_deposited += _amount;
        emit NewDeposit(_addr, _amount);
    }


    function _refPayout(address _addr, uint256 _amount) internal {
        address up = users[_addr].upline;
        require(ref_bonuses.length <= statusContract.getStatusLines(statusContract.getAddressStatus(_addr)),
                                            "WordLexStaking: Unavailable lines, please, Update status");

        for(uint8 i = 0; i < ref_bonuses.length; i++) {
            if(up == address(0)) break;

            if(users[up].referrals >= i + 1) {
                uint256 bonus = _amount.mul(ref_bonuses[i]).div(100);
                users[up].matchBonus += bonus;
                emit MatchPayout(up, _addr, bonus);
            }
            up = users[up].upline;
        }
    }


    /**
    ###################################################################################
    ##############################  Геттеры ###########################################
    ###################################################################################
    */
    function maxDailyPayoutOf(address _statusHolder)public view returns(uint256) {
        return statusContract.getStatusLimit(statusContract.getAddressStatus(_statusHolder));
    }


    function payoutOf(address _addr) public view returns(uint256 payout, uint256 max_payout) {
        max_payout = this.maxDailyPayoutOf(_addr);
        if(users[_addr].depositPayouts < max_payout) {

            payout = (users[_addr].depositAmount.mul(
                (block.timestamp.sub(users[_addr].depositTime)).div(1 days)
                ).mul(getDailyPercent(_addr)).div(1000)).sub(users[_addr].depositPayouts);

            if(users[_addr].depositPayouts.add(payout) > max_payout) {
                payout = max_payout.sub(users[_addr].depositPayouts);
            }
        }
    }


    function getDailyPercent(address _addr) public view returns(uint256 _dailyPercent) {
        _dailyPercent = minimumDailyPercent;
        if (users[_addr].depositAmount > 2e11) { // 200,000 WDX
            _dailyPercent = minimumDailyPercent.add(4);
        }
        if (users[_addr].depositAmount > 1e11) {
            _dailyPercent = minimumDailyPercent.add(3);
        }
        if (users[_addr].depositAmount > 2e10) {
            _dailyPercent = minimumDailyPercent.add(2);
        }
        if (users[_addr].depositAmount > 1e10) {
            _dailyPercent = minimumDailyPercent.add(1);
        }

        if (block.timestamp > users[_addr].depositTime.add(548 days)) {
            _dailyPercent = _dailyPercent.add(5);
        }
        if (block.timestamp > users[_addr].depositTime.add(365 days)) {
            _dailyPercent = _dailyPercent.add(4);
        }
        if (block.timestamp > users[_addr].depositTime.add(180 days)) {
            _dailyPercent = _dailyPercent.add(3);
        }
        if (block.timestamp > users[_addr].depositTime.add(90 days)) {
            _dailyPercent = _dailyPercent.add(2);
        }
        if (block.timestamp > users[_addr].depositTime.add(30 days)) {
            _dailyPercent = _dailyPercent.add(1);
        }
    }


    function userInfo(address _addr)public view returns(address upline,
                                                        uint40 depositTime,
                                                        uint256 depositAmount,
                                                        uint256 payouts,
                                                        uint256 matchBonus) {
        return (users[_addr].upline,
                users[_addr].depositTime,
                users[_addr].depositAmount,
                users[_addr].payouts,
                users[_addr].matchBonus);
    }


    function userInfoTotals(address _addr)public view returns(uint256 referrals,
                                                                uint256 totalDeposits,
                                                                uint256 totalPayouts,
                                                                uint256 totalStructure) {
        return (users[_addr].referrals,
                users[_addr].totalDeposits,
                users[_addr].totalPayouts,
                users[_addr].totalStructure);
    }


    function contractInfo()public view  returns(uint256 _total_users,
                                                uint256 _total_deposited,
                                                uint256 _total_withdraw) {
        return (total_users, total_deposited, total_withdraw);
    }

}