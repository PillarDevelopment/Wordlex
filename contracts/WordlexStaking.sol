// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.0;

import  "./ITRC20.sol";
import "./IWordlexStatus.sol";
import "./Ownable.sol";
import "./SafeMath.sol";

contract WordlexStaking is Ownable{
    using SafeMath for uint256;
    using SafeMath for uint40;

    struct User {
        address upline;
        uint256 referrals;
        uint256 payouts;
        uint256 match_bonus;
        uint256 deposit_amount;
        uint256 deposit_payouts;
        uint40 deposit_time;
        uint256 withdraw_time;
        uint256 total_deposits;
        uint256 total_payouts;
        uint256 total_structure;
    }

    ITRC20 public WDX;
    IWordlexStatus public statusContract;

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

    constructor(ITRC20 _wdx, IWordlexStatus _statusContract) public {
        WDX = _wdx;
        statusContract = _statusContract;

        ref_bonuses.push(5);
        ref_bonuses.push(5);
        ref_bonuses.push(5);
        ref_bonuses.push(5);
        ref_bonuses.push(5);
        ref_bonuses.push(5);
        ref_bonuses.push(5);
        ref_bonuses.push(5);
        ref_bonuses.push(5);
        ref_bonuses.push(5);
    }


    /**
     ###################################################################################
     ##############################  External          #################################
     ###################################################################################
     */
    function deposit(address _upline, uint256 _amount)  public {
        _setUpline(msg.sender, _upline);
        _deposit(msg.sender, _amount);
        WDX.transferFrom(msg.sender, address(this), _amount);
    }


    function withdraw() public {

        (uint256 to_payout, uint256 max_payout) = this.payoutOf(msg.sender);
        require(users[msg.sender].withdraw_time.add(7 days) < block.timestamp, "WordlexStaking: Less than 7 days have passed since the last withdrawal");

        if(to_payout > 0) {
            if(users[msg.sender].payouts.add(to_payout)  > max_payout) {
                to_payout = max_payout.sub(users[msg.sender].payouts);
            }

            users[msg.sender].deposit_payouts += to_payout;
            users[msg.sender].payouts += to_payout;

            _refPayout(msg.sender, to_payout);
        }

        if(users[msg.sender].payouts < max_payout && users[msg.sender].match_bonus > 0) {
            uint256 match_bonus = users[msg.sender].match_bonus;

            if(users[msg.sender].payouts.add(match_bonus) > max_payout) {
                match_bonus = max_payout.sub(users[msg.sender].payouts);
            }

            users[msg.sender].match_bonus -= match_bonus;
            users[msg.sender].payouts += match_bonus;
            to_payout += match_bonus;
        }

        require(to_payout > 0, "WordlexStaking: Zero payout");

        users[msg.sender].total_payouts += to_payout;
        total_withdraw += to_payout;
        users[msg.sender].withdraw_time = block.timestamp;
        WDX.transfer(msg.sender, to_payout);

        emit Withdraw(msg.sender, to_payout);

        if(users[msg.sender].payouts >= max_payout) {
            emit LimitReached(msg.sender, users[msg.sender].payouts);
        }
    }


    /**
    ###################################################################################
    ##############################  внутренние методы #################################
    ###################################################################################
    */
    function _setUpline(address _addr, address _upline) private {
        if(users[_addr].upline == address(0) && _upline != _addr && _addr != owner() && (users[_upline].deposit_time > 0 || _upline == owner())) {
            users[_addr].upline = _upline;
            users[_upline].referrals++;

            emit Upline(_addr, _upline);
            total_users++;

            for(uint8 i = 0; i < ref_bonuses.length; i++) {
                if(_upline == address(0)) break;

                users[_upline].total_structure++;

                _upline = users[_upline].upline;
            }
        }
    }


    function _deposit(address _addr, uint256 _amount) private {
        require(users[_addr].upline != address(0) || _addr == owner(), "WordlexStaking: No upline");

        users[_addr].payouts = 0;
        users[_addr].deposit_amount = _amount;
        users[_addr].deposit_payouts = 0;
        users[_addr].deposit_time = uint40(block.timestamp);
        users[_addr].total_deposits += _amount;

        total_deposited += _amount;
        emit NewDeposit(_addr, _amount);
    }


    function _refPayout(address _addr, uint256 _amount) private {
        address up = users[_addr].upline;
        require(ref_bonuses.length <= statusContract.getStatusLines(statusContract.getAddressStatus(_addr)), "WordlexStaking: Unavailable lines, please, update status");

        for(uint8 i = 0; i < ref_bonuses.length; i++) {
            if(up == address(0)) break;

            if(users[up].referrals >= i + 1) {
                uint256 bonus = _amount.mul(ref_bonuses[i]).div(100);

                users[up].match_bonus += bonus;

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
    function maxDailyPayoutOf(address _statusHolder) view public returns(uint256) {
        return statusContract.getStatusLimit(statusContract.getAddressStatus(_statusHolder));
    }


    function payoutOf(address _addr) external view returns(uint256 payout, uint256 max_payout) {
        max_payout = this.maxDailyPayoutOf(_addr);

        if(users[_addr].deposit_payouts < max_payout) {

            payout = (users[_addr].deposit_amount.mul((block.timestamp.sub(users[_addr].deposit_time)).div(1 days)).mul(getDailyPercent(_addr)).div(1000)).sub(users[_addr].deposit_payouts);

            if(users[_addr].deposit_payouts.add(payout) > max_payout) {
                payout = max_payout.sub(users[_addr].deposit_payouts);
            }
        }
    }


    function getDailyPercent(address _addr) internal view returns(uint256 _dailyPercent) {
        _dailyPercent = minimumDailyPercent;
        if (users[_addr].deposit_amount > 2e11) { // 200,000 WDX
            _dailyPercent = minimumDailyPercent.add(4);
        }
        if (users[_addr].deposit_amount > 1e11) {
            _dailyPercent = minimumDailyPercent.add(3);
        }
        if (users[_addr].deposit_amount > 2e10) {
            _dailyPercent = minimumDailyPercent.add(2);
        }
        if (users[_addr].deposit_amount > 1e10) {
            _dailyPercent = minimumDailyPercent.add(1);
        }

        if (block.timestamp > users[_addr].deposit_time.add(548 days)) {
            _dailyPercent = _dailyPercent.add(5);
        }
        if (block.timestamp > users[_addr].deposit_time.add(365 days)) {
            _dailyPercent = _dailyPercent.add(4);
        }
        if (block.timestamp > users[_addr].deposit_time.add(180 days)) {
            _dailyPercent = _dailyPercent.add(3);
        }
        if (block.timestamp > users[_addr].deposit_time.add(90 days)) {
            _dailyPercent = _dailyPercent.add(2);
        }
        if (block.timestamp > users[_addr].deposit_time.add(30 days)) {
            _dailyPercent = _dailyPercent.add(1);
        }
    }


    function userInfo(address _addr) view public returns(address upline, uint40 deposit_time, uint256 deposit_amount, uint256 payouts, uint256 match_bonus) {
        return (users[_addr].upline, users[_addr].deposit_time, users[_addr].deposit_amount, users[_addr].payouts, users[_addr].match_bonus);
    }


    function userInfoTotals(address _addr) view public returns(uint256 referrals, uint256 total_deposits, uint256 total_payouts, uint256 total_structure) {
        return (users[_addr].referrals, users[_addr].total_deposits, users[_addr].total_payouts, users[_addr].total_structure);
    }


    function contractInfo() view public returns(uint256 _total_users, uint256 _total_deposited, uint256 _total_withdraw) {
        return (total_users, total_deposited, total_withdraw);
    }

}