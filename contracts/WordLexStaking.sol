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

    ITRC20 public wdxToken;
    IWordLexStatus public statusContract;

    mapping(address => User) public users;
    uint8[] public refBonuses;

    uint256 public totalUsers = 1;
    uint256 public totalDeposited;
    uint256 public totalWithdraw;
    uint256 public minimumDailyPercent = 6;

    event Upline(address indexed addr, address indexed upline);
    event NewDeposit(address indexed addr, uint256 amount);
    event MatchPayout(address indexed addr, address indexed from, uint256 amount);
    event Withdraw(address indexed addr, uint256 amount);

    constructor(ITRC20 _wdx, IWordLexStatus _statusContract) public {
        wdxToken = _wdx;
        statusContract = _statusContract;

        refBonuses.push(20);
        refBonuses.push(20);
        refBonuses.push(20);
        refBonuses.push(20);
        refBonuses.push(20);
        refBonuses.push(20);
        refBonuses.push(20);
        refBonuses.push(20);
        refBonuses.push(20);
        refBonuses.push(20);
    }

    function deposit(address _upline, uint256 _amount)  public {
        _setUpline(msg.sender, _upline);
        _deposit(msg.sender, _amount);
        wdxToken.transferFrom(msg.sender, address(this), _amount);
    }


    function withdraw(uint256 _amount) public {
        require(_amount <= users[msg.sender].depositAmount, "WordLexStaking:incorrect amount, try less");

        (uint256 toPayout, uint256 maxPayout) = this.payoutOf(msg.sender, _amount);
        if (toPayout >= _amount) {
            toPayout == _amount;
        }

        require(users[msg.sender].withdrawTime.add(7 days) < block.timestamp,
                "WordLexStaking: Less than 7 days have passed since the last withdrawal");

        if(toPayout > 0) {
            if(users[msg.sender].payouts.add(toPayout) > maxPayout) {
                toPayout = maxPayout.sub(users[msg.sender].payouts);
            }
            users[msg.sender].depositPayouts += toPayout;
            users[msg.sender].payouts += toPayout;
            _refPayout(msg.sender, toPayout);
        }

        if(users[msg.sender].payouts < maxPayout && users[msg.sender].matchBonus > 0) {
            uint256 matchBonus = users[msg.sender].matchBonus;

            if(users[msg.sender].payouts.add(matchBonus) > maxPayout) {
                matchBonus = maxPayout.sub(users[msg.sender].payouts);
            }

            users[msg.sender].matchBonus -= matchBonus;
            users[msg.sender].payouts += matchBonus;
            toPayout += matchBonus;
        }

        require(toPayout > 0, "WordLexStaking: Zero payout");

        users[msg.sender].totalPayouts += toPayout;
        totalWithdraw += toPayout;
        users[msg.sender].withdrawTime = block.timestamp;
        users[msg.sender].depositAmount -= _amount;

        wdxToken.transfer(msg.sender, toPayout);
        emit Withdraw(msg.sender, toPayout);
    }


    function maxDailyPayoutOf(address _statusHolder)public view returns(uint256) {
        return statusContract.getStatusLimit(statusContract.getAddressStatus(_statusHolder));
    }


    function payoutOf(address _addr, uint256 _amount) public view returns(uint256 payout, uint256 maxPayout) {
        maxPayout = this.maxDailyPayoutOf(_addr);

        if(_amount < maxPayout) {

            payout = generateCompoundInterest(_addr, _amount);

            if(users[_addr].depositPayouts.add(payout) > maxPayout) {
                payout = maxPayout.sub(users[_addr].depositPayouts);
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


    function contractInfo()public view  returns(uint256 _totalUsers,
                                                uint256 _totalDeposited,
                                                uint256 _totalWithdraw) {
        return (totalUsers, totalDeposited, totalWithdraw);
    }


    function generateCompoundInterest(address _addr, uint256 amount) public view returns(uint256) {
        uint256 accAmount = amount;
        uint256 accDay = uint40(block.timestamp).div(users[_addr].depositTime);
        uint256 currentPercent = getDailyPercent(_addr);

        for (uint256 i = 0; i < accDay; i++) {
            accAmount = accAmount.mul(currentPercent).div(1000);  // на каждой итерации получаем общую сумму бонусов и умножаем ее на процент
        }
        return accAmount;
    }


    function _setUpline(address _addr, address _upline) internal {
        if(users[_addr].upline == address(0) && _upline != _addr
            && _addr != owner() && (users[_upline].depositTime > 0 || _upline == owner())) {
            users[_addr].upline = _upline;
            users[_upline].referrals++;

            emit Upline(_addr, _upline);
            totalUsers++;

            for(uint8 i = 0; i < refBonuses.length; i++) {
                if(_upline == address(0)) break;
                users[_upline].totalStructure++;
                _upline = users[_upline].upline;
            }
        }
    }


    function _deposit(address _addr, uint256 _amount) internal {
        require(users[_addr].upline != address(0) || _addr == owner(), "WordLexStaking: No upLine");
        users[_addr].depositAmount = users[_addr].depositAmount.add(_amount);

        if (users[_addr].depositTime == 0) {
            users[_addr].depositTime = uint40(block.timestamp);
        }

        users[_addr].totalDeposits += _amount;
        totalDeposited += _amount;
        emit NewDeposit(_addr, _amount);
    }


    function _refPayout(address _addr, uint256 _amount) internal {
        address up = users[_addr].upline;
        require(refBonuses.length <= statusContract.getStatusLines(statusContract.getAddressStatus(_addr)),
                                            "WordLexStaking: Unavailable lines, please, Update status");

        for(uint8 i = 0; i < refBonuses.length; i++) {
            if(up == address(0)) break;

            if(users[up].referrals >= i + 1) {
                uint256 bonus = _amount.mul(refBonuses[i]).div(100);
                users[up].matchBonus += bonus;
                emit MatchPayout(up, _addr, bonus);
            }
            up = users[up].upline;
        }
    }

}