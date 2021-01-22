// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.0;

import  "./ITRC20.sol";
import "./IWordlexStatus.sol";
import "./Ownable.sol";

contract AutoProgramWordlex is Ownable {

    struct User {
        address upline;
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
        bool statusOfCar;
        uint256 activeUsers; // кто купил машину у юзера в структуре // todo
    }

    ITRC20 public WDX;
    IWordlexStatus public statusContract;

    mapping(address => User) public users;
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
    function buyCar(address _upline, uint256 _amount)  public {
        _setUpline(msg.sender, _upline);
        require(_amount == users[msg.sender].carPrice, "AutoProgram: Incorrect amount");
        _deposit(msg.sender, _amount);
        WDX.transferFrom(msg.sender, address(this), _amount);
    }


    function withdraw() public {

        if (users[msg.sender].direct_bonus == 0 || users[msg.sender].direct_bonus == users[msg.sender].carPrice && users[msg.sender].deposit_time + 365 days < block.timestamp ) {
            revert();
        }

        if (users[msg.sender].deposit_time + 15768000 >= block.timestamp && users[msg.sender].direct_bonus == 0) {
            users[users[msg.sender].upline].match_bonus += users[msg.sender].match_bonus;
            users[msg.sender].match_bonus = 0;
        }

        (uint256 to_payout, uint256 max_payout) = this.payoutOf(msg.sender);

        if(users[msg.sender].direct_bonus >= users[msg.sender].carPrice*3) { //todo  users[msg.sender].carPriceInWDX >= carPriceInWDX его 3х из первой линии * 3
            users[msg.sender].statusOfCar = true;
        }


        require(users[msg.sender].deposit_time + 15768000 < block.timestamp || users[msg.sender].statusOfCar == true, "AutoProgram: Less than 6 months have passed since the last car Sell");

        if(to_payout > 0) {
            if(users[msg.sender].payouts + to_payout > max_payout) {
                to_payout = max_payout - users[msg.sender].payouts;
            }

            users[msg.sender].deposit_payouts += to_payout;
            users[msg.sender].payouts += to_payout;

            _refPayout(msg.sender, to_payout);
        }

        if(users[msg.sender].payouts < max_payout && users[msg.sender].match_bonus > 0) {
            uint256 match_bonus = users[msg.sender].match_bonus;

            if(users[msg.sender].payouts + match_bonus > max_payout) {
                match_bonus = max_payout - users[msg.sender].payouts;
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
        require(users[_addr].upline != address(0) || _addr == owner(), "AutoProgram: No upline");

        users[_addr].payouts = 0;
        users[_addr].deposit_amount = _amount;
        users[_addr].deposit_payouts = 0;
        users[_addr].deposit_time = uint40(block.timestamp);
        users[_addr].total_deposits += _amount;

        total_deposited += _amount;

        emit NewDeposit(_addr, _amount);

        if(users[_addr].upline != address(0)) {
            users[users[_addr].upline].direct_bonus += _amount*3 / 100; // 3%

            emit DirectPayout(users[_addr].upline, _addr, _amount*3 / 100);
        }
    }


    function _refPayout(address _addr, uint256 _amount) private {
        address up = users[_addr].upline;

        require(ref_bonuses.length <= statusContract.getStatusLines(statusContract.getAddressStatus(_addr)), "AutoProgram: : Unavailable lines, please, update status");

        for(uint8 i = 0; i < ref_bonuses.length; i++) {
            if(up == address(0)) break;

            if(users[up].referrals >= i + 1) {
                uint256 bonus = _amount * ref_bonuses[i] / 1000; // 0,4% every line

                users[up].match_bonus += bonus;

                emit MatchPayout(up, _addr, bonus);
            }
            up = users[up].upline;
        }
    }


    function maxDailyPayoutOf(address _statusHolder) view public returns(uint256) {
        return statusContract.getStatusLimit(statusContract.getAddressStatus(_statusHolder));
    }


    function payoutOf(address _addr) view external returns(uint256 payout, uint256 max_payout) {
        max_payout = this.maxDailyPayoutOf(_addr);

        if(users[_addr].deposit_payouts < max_payout) {

            payout = (users[_addr].deposit_amount * ((block.timestamp - users[_addr].deposit_time) / 1 days)/ 1000) - users[_addr].deposit_payouts;

            if(users[_addr].deposit_payouts + payout > max_payout) {
                payout = max_payout - users[_addr].deposit_payouts;
            }
        }
    }


    function userInfo(address _addr) view public returns(address upline,
                                                        uint40 deposit_time,
                                                        uint256 deposit_amount,
                                                        uint256 payouts,
                                                        uint256 match_bonus,
                                                        bool statusOfCar) {
        return (users[_addr].upline,
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


    function setUserCarPrice(address _user, uint256 _newWDXPrice) public onlyOwner {
        users[_user].carPrice = _newWDXPrice;
    }


    //когда пользотваель сам покупает - мы делаем ему статус
    //добавить счетчик сколько купили автомобилей в первой линии -
    //если у него больше 1го купил - помечаем его аккаунт как активный
    // если купил сам или купил кто то из 1й линии
    // найти ближайший вверх activeAccount

}