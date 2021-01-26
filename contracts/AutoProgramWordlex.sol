// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.0;

import  "./ITRC20.sol";
import "./IWordlexStatus.sol";
import "./Ownable.sol";
import "./SafeMath.sol";

contract AutoProgramWordlex is Ownable {
    using SafeMath for uint256;
    using SafeMath for uint40;
    using SafeMath for uint8;

    struct User {
        address upLine;
        uint256 referrals;
        uint256 payouts;
        uint256 direct_bonus;
        uint256 match_bonus;
        uint256 deposit_amount;
        uint256 deposit_payouts;
        uint40 deposit_time;
        uint256 total_deposits;
        uint256 total_payouts;
        uint256 total_structure;
        uint256 carPrice;
        bool statusOfCar; // activeAccount
        uint256[] firstLineIds;
    }

    ITRC20 public WDX;
    IWordlexStatus public statusContract;

    mapping(address => User) public users;
    address[] public ids;
    uint8[] public ref_bonuses;

    uint256 public total_users = 1;
    uint256 public total_deposited;
    uint256 public total_withdraw;

    event Upline(address indexed addr, address indexed upline);
    event NewDeposit(address indexed addr, uint256 amount);
    event DirectPayout(address indexed addr, address indexed from, uint256 amount);
    event MatchPayout(address indexed addr, address indexed from, uint256 amount);
    event Withdraw(address indexed addr, uint256 amount);
    event LimitReached(address indexed addr, uint256 amount);
    event LiquidatedInactive(address indexed inactiveAccount, address indexed liquidator, uint256 amount);

    constructor(ITRC20 _wdx, IWordlexStatus _statusContract) public {
        WDX = _wdx;
        statusContract = _statusContract;

        ref_bonuses.push(4); // 0,4
        ref_bonuses.push(4); // 0,4
        ref_bonuses.push(4); // 0,4
        ref_bonuses.push(4); // 0,4
        ref_bonuses.push(4); // 0,4
        ref_bonuses.push(4); // 0,4
        ref_bonuses.push(4); // 0,4
        ref_bonuses.push(4); // 0,4
        ref_bonuses.push(4); // 0,4
        ref_bonuses.push(4); // 0,4
    }


    /**
     ###################################################################################
     ##############################  External          #################################
     ###################################################################################
     */
    function buyCar(uint256 _amount)  public {

        require(_amount == users[msg.sender].carPrice && users[msg.sender].carPrice != 0, "AutoProgram: Invalid amount or carPrice isn't determined");
        require(users[msg.sender].upLine != address(0x0), "AutoProgramWDX: Address not registered");
        _deposit(msg.sender, _amount);
        WDX.transferFrom(msg.sender, address(this), _amount);
        users[msg.sender].statusOfCar = true;
    }


    function registration(address _upline, uint256 _carPrice, address _addr) public onlyOwner {
        _setUpline(_addr, _upline);
        users[_addr].carPrice = _carPrice;
        users[_addr].statusOfCar = false;
    }


    function withdraw() public {

        if (users[msg.sender].direct_bonus == 0 || users[msg.sender].direct_bonus == users[msg.sender].carPrice && users[msg.sender].deposit_time.add(365 days)  < block.timestamp ) {
            revert();
        }

        if (users[msg.sender].deposit_time.add(180 days)  >= block.timestamp && users[msg.sender].direct_bonus == 0) {
            users[users[msg.sender].upLine].match_bonus += users[msg.sender].match_bonus;
            users[msg.sender].match_bonus = 0;
        }

        (uint256 to_payout, uint256 max_payout) = this.payoutOf(msg.sender);

      //  if(users[msg.sender].direct_bonus >= users[msg.sender].carPrice.mul(3)) { //todo  users[msg.sender].carPriceInWDX >= carPriceInWDX его 3х из первой линии * 3
      //      users[msg.sender].statusOfCar = true;
      //  }

        require(users[msg.sender].deposit_time.add(180 days)  < block.timestamp || users[msg.sender].statusOfCar == true, "AutoProgram: Less than 6 months have passed since the last car Sell");

        if(to_payout > 0) {
            if(users[msg.sender].payouts.add(to_payout) > max_payout) {
                to_payout = max_payout.sub(users[msg.sender].payouts);
            }

            users[msg.sender].deposit_payouts += to_payout;
            users[msg.sender].payouts += to_payout;

            _refPayout(msg.sender, to_payout);
        }

        if(users[msg.sender].payouts < max_payout && users[msg.sender].match_bonus > 0) {
            uint256 match_bonus = users[msg.sender].match_bonus;

            if(users[msg.sender].payouts.add(match_bonus)  > max_payout) {
                match_bonus = max_payout.sub(users[msg.sender].payouts);
            }

            users[msg.sender].match_bonus -= match_bonus;
            users[msg.sender].payouts += match_bonus;
            to_payout += match_bonus;
        }

        require(to_payout > 0, "AutoProgram: Zero payout");

        users[msg.sender].total_payouts += to_payout;
        total_withdraw += to_payout;

        WDX.transfer(msg.sender, to_payout);

        emit Withdraw(msg.sender, to_payout);
        if(users[msg.sender].payouts >= max_payout) {
            emit LimitReached(msg.sender, users[msg.sender].payouts);
        }
    }


    function liquidateInactiveAccount(address inactiveAccount) public {
        require(users[inactiveAccount].statusOfCar == false && users[inactiveAccount].total_structure == 0 &&
            users[inactiveAccount].deposit_time.add(180 days) < now &&
            users[inactiveAccount].deposit_amount != 0, "AutoProgramWDX: This address isn't inactive or not available");

        WDX.transfer(msg.sender, users[inactiveAccount].deposit_amount);
        users[inactiveAccount].deposit_amount = 0;
        emit LiquidatedInactive(inactiveAccount, msg.sender, users[inactiveAccount].deposit_amount);
    }


    function _setUpline(address _addr, address _upLine) private {
        if(users[_addr].upLine == address(0) && _upLine != _addr && _addr != owner() && (users[_upLine].deposit_time > 0 || _upLine == owner())) {
            users[_addr].upLine = _upLine;
            users[_upLine].referrals++;

            emit Upline(_addr, _upLine);
            total_users++;
            ids.push(_addr);
            users[_upLine].firstLineIds.push(ids.length);

            for(uint8 i = 0; i < ref_bonuses.length; i++) {
                if(_upLine == address(0)) break;
                users[_upLine].total_structure++;
                _upLine = users[_upLine].upLine;
            }
        }
    }


    function _deposit(address _addr, uint256 _amount) private {
        require(users[_addr].upLine != address(0) || _addr == owner(), "AutoProgram: No upLine");

        users[_addr].payouts = 0;
        users[_addr].deposit_amount = _amount;
        users[_addr].deposit_payouts = 0;
        users[_addr].deposit_time = uint40(block.timestamp);
        users[_addr].total_deposits += _amount;

        total_deposited += _amount;
        emit NewDeposit(_addr, _amount);

        if(users[_addr].upLine != address(0) ) {
            users[users[_addr].upLine].direct_bonus += _amount.mul(5).div(100);
            emit DirectPayout(users[_addr].upLine, _addr, _amount.mul(5).div(100));
        }
    }


    function _refPayout(address _addr, uint256 _amount) private {
        address up = users[_addr].upLine;

        require(ref_bonuses.length <= statusContract.getStatusLines(statusContract.getAddressStatus(_addr)), "AutoProgram: Unavailable lines, please, update status");

        for(uint8 i = 0; i < ref_bonuses.length; i++) {
            if(up == address(0)) break;

            if(users[up].referrals >= i + 1) {
                uint256 bonus = _amount.mul(ref_bonuses[i].div(1000)); // 0,4% every line

                users[up].match_bonus += bonus;
                emit MatchPayout(up, _addr, bonus);
            }
            up = users[up].upLine;
        }
    }


    function maxDailyPayoutOf(address _addr) view public returns(uint256) {
        return statusContract.getStatusLimit(statusContract.getAddressStatus(_addr));
    }


    function payoutOf(address _addr) view external returns(uint256 payout, uint256 max_payout) {
        max_payout = this.maxDailyPayoutOf(_addr);

        if(users[_addr].deposit_payouts < max_payout) {

            payout = (users[_addr].deposit_amount.mul((block.timestamp.sub(users[_addr].deposit_time).div(1 days)).div(1000)).sub(users[_addr].deposit_payouts));

            if(users[_addr].deposit_payouts.add(payout)  > max_payout) {
                payout = max_payout.sub(users[_addr].deposit_payouts);
            }
        }
    }


    function userInfo(address _addr) view public returns(address upline,
                                                        uint40 deposit_time,
                                                        uint256 deposit_amount,
                                                        uint256 payouts,
                                                        uint256 match_bonus,
                                                        bool statusOfCar) {
        return (users[_addr].upLine,
                users[_addr].deposit_time,
                users[_addr].deposit_amount,
                users[_addr].payouts,
                users[_addr].match_bonus,
                users[_addr].statusOfCar);
    }


    function userInfoTotals(address _addr) view public returns(uint256 referrals,
                                                                uint256 total_deposits,
                                                                uint256 total_payouts,
                                                                uint256 total_structure) {
        return (users[_addr].referrals,
                users[_addr].total_deposits,
                users[_addr].total_payouts,
                users[_addr].total_structure);
    }


    function contractInfo() view public returns(uint256 _total_users, uint256 _total_deposited, uint256 _total_withdraw) {
        return (total_users, total_deposited, total_withdraw);
    }


    function setUserCarPrice(address _addr, uint256 _newWDXPrice) public onlyOwner {
        users[_addr].carPrice = _newWDXPrice;
    }


    //когда пользотваель сам покупает - мы делаем ему статус
    //добавить счетчик сколько купили автомобилей в первой линии -
    //если у него больше 1го купил - помечаем его аккаунт как активный
    // если купил сам или купил кто то из 1й линии
    // найти ближайший вверх activeAccount

}