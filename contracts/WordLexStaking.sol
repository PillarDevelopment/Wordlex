// SPDX-License-Identifier: MIT
pragma solidity ^0.5.8;

import  "./ITRC20.sol";
import "./IWordLexStatus.sol";
import "./Ownable.sol";
import "./SafeMath.sol";

contract WordLexStaking is Ownable{
    using SafeMath for uint256;

    struct User {
        address upline;
        uint256 referrals;
        uint256 payouts;
        uint256 matchBonus;
        uint256 depositAmount;
        uint256 depositTime;
        uint256 withdrawTime;
        uint256 totalDeposits;
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
        require(users[msg.sender].withdrawTime.add(7 days) < block.timestamp,
            "WordLexStaking: Less than 7 days have passed since the last withdrawal");

        uint256 toPayout = this.payoutOf(msg.sender, _amount);

        if(toPayout > 0) {
            users[msg.sender].payouts += toPayout;
            _refPayout(msg.sender, toPayout);
        }

        if(users[msg.sender].matchBonus > 0) {
            uint256 matchBonus = users[msg.sender].matchBonus;

            users[msg.sender].matchBonus -= matchBonus;
            users[msg.sender].payouts += matchBonus;
            toPayout += matchBonus;
        }

        require(toPayout > 0, "WordLexStaking: Zero payout");

        totalWithdraw += toPayout;
        users[msg.sender].withdrawTime = block.timestamp;
        users[msg.sender].depositAmount -= _amount;

        wdxToken.transfer(msg.sender, toPayout);
        emit Withdraw(msg.sender, toPayout);
    }


    function setMinimumDailyPercent(uint256 _newPercent) public onlyOwner {
        minimumDailyPercent = _newPercent;
    }


    function setRefBonusesPercentage(uint256 line, uint8 newAmount) public onlyOwner{
        require(refBonuses.length > line, "WordLexStaking:unavailable line");
        refBonuses[line] = newAmount;
    }


    function maxDailyPayoutOf(address _statusHolder)public view returns(uint256) {
        return statusContract.getStatusLimit(statusContract.getAddressStatus(_statusHolder));
    }


    function payoutOf(address _addr, uint256 _amount) public view returns(uint256 payout) {
        uint256 maxPayout = this.maxDailyPayoutOf(_addr);

        if(_amount <= maxPayout) {

            payout = generateCompoundInterest(_addr, _amount);
        }
        else {
            payout = 0;
        }
    }


    function getDailyPercent(address _addr) public view returns(uint256 _dailyPercent) {
        return minimumDailyPercent.add(getDepositHoldBonus(users[_addr].depositAmount)).add(getTimeBonus(users[_addr].depositTime));
    }


    function getTimeBonus(uint256 _depositTime) public view returns(uint256 _dailyTimeBonus) {
        if (block.timestamp > _depositTime.add(30 days)) {
            _dailyTimeBonus = 1;
        }
        if (block.timestamp > _depositTime.add(90 days)) {
            _dailyTimeBonus = 2;
        }
        if (block.timestamp > _depositTime.add(180 days)) {
            _dailyTimeBonus = 3;
        }
        if (block.timestamp > _depositTime.add(365 days)) {
            _dailyTimeBonus = 4;
        }
        if (block.timestamp > _depositTime.add(548 days)) {
            _dailyTimeBonus = 5;
        }
        return _dailyTimeBonus;
    }


    function getDepositHoldBonus(uint256 _depositAmount) public pure returns(uint256 _dailyHoldBonus) {
        if (_depositAmount > 10000000000) { // 10,000 WDX
            _dailyHoldBonus = 1;
        }
        if (_depositAmount > 20000000000) { // 20,000 WDX
            _dailyHoldBonus = 2;
        }
        if (_depositAmount > 100000000000) { // 100,000 WDX
            _dailyHoldBonus = 3;
        }
        if (_depositAmount > 200000000000) { // 200,000 WDX
            _dailyHoldBonus = 4;
        }
        return _dailyHoldBonus;
    }


    function userInfo(address _addr)public view returns(address upline,
                                                        uint256 depositTime,
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
                                                                uint256 totalStructure) {
        return (users[_addr].referrals,
                users[_addr].totalDeposits,
                users[_addr].totalStructure);
    }


    function contractInfo()public view  returns(uint256 _totalUsers,
                                                uint256 _totalDeposited,
                                                uint256 _totalWithdraw) {
        return (totalUsers, totalDeposited, totalWithdraw);
    }


    function generateCompoundInterest(address _addr, uint256 amount) public view returns(uint256) {
        uint256 accAmount = amount;
        uint256 accDay = (block.timestamp.sub(users[_addr].depositTime)).div(1 days);
        uint256 currentPercent = getDailyPercent(_addr);

        if (accDay > 1) {
            for (uint256 i = 0; i < accDay; i++) {
                accAmount = accAmount.add(accAmount.mul(currentPercent).div(1000));
            }
        }
        else {
            accAmount = 0;
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
            users[_addr].depositTime = block.timestamp;
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