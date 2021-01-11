pragma solidity ^0.5.12;

import "./Interfaces\IWordlexStatus.sol";

interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IWordlexStatus {

    function getStatusPrice(uint256 _statusId) external view returns(uint256);

    function getAddressStatus(address _statusHolder) external view returns(uint256);

    function getStatusUSDPrice(uint256 _statusId) external view returns(uint256);

    function getStatusLimit(uint256 _statusId) external view returns(uint256);

    function getStatusLines(uint256 _statusId) external view returns(uint256);

    function getStatusName(uint256 _statusId) external view returns(string memory);
}

contract AutoProgramWordlex {

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
        //uint256 timeOfCarSell;
        bool statusOfCar; // true - если в програме // false - если нет
    }

    address payable public owner;
    IERC20 public WDX;
    IWordlexStatus public statusContract;

    mapping(address => User) public users;
    uint8[] public ref_bonuses;
    uint256 private carPriceInWDX;

    uint256 public total_users = 1;
    uint256 public total_deposited;
    uint256 public total_withdraw;

    event Upline(address indexed addr, address indexed upline);
    event NewDeposit(address indexed addr, uint256 amount);
    event DirectPayout(address indexed addr, address indexed from, uint256 amount);
    event MatchPayout(address indexed addr, address indexed from, uint256 amount);
    event Withdraw(address indexed addr, uint256 amount);
    event LimitReached(address indexed addr, uint256 amount);

    constructor(address payable _owner, IERC20 _wdx, IWordlexStatus _statusContract) public {
        owner = _owner;
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
        require(_amount == carPriceInWDX);
        WDX.transferFrom(msg.sender, address(this), _amount);
        _deposit(msg.sender, msg.value);
    }


    function withdraw() public {
        // если direct_bonus = price*3 - то получает права и возможность вывода
        // если не так - то через 1 год (без 3х друзей)
        // если он покупает авто или открывает линию - то вознаграждение будет
        if (users[msg.sender].direct_bonus == 0 || users[msg.sender].direct_bonus == carPriceInWDX && users[msg.sender].deposit_time + 15768000 < block.timestamp ) {
            // или покупка только 1 авто 1 рефералом 1 линии
            // если direct_bonus == 0
            revert();
            // его вознаграждение замораживается на 6 месяцев
        }

        if (users[msg.sender].deposit_time + 15768000 >= block.timestamp && users[msg.sender].direct_bonus == 0) {
            // если через 6 месяцев от deposit_time он не привел рефералов - то вознаграждения идет _setUpline
            users[users[msg.sender].upline].match_bonus += users[msg.sender].match_bonus;
            users[msg.sender].match_bonus = 0;
        }

        (uint256 to_payout, uint256 max_payout) = this.payoutOf(msg.sender);
       // require(users[msg.sender].deposit_time + 15768000 < block.timestamp || users[msg.sender].statusOfCar == true, "Less than 6 months have passed since the last car Sell");

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

        require(to_payout > 0, "Zero payout");

        users[msg.sender].total_payouts += to_payout;
        total_withdraw += to_payout;
        users[msg.sender].withdraw_time = block.timestamp;
        WDX.transfer(msg.sender, to_payout);

        emit Withdraw(msg.sender, to_payout);

        if(users[msg.sender].payouts >= max_payout) {
            emit LimitReached(msg.sender, users[msg.sender].payouts);
        }
    }


    function _setUpline(address _addr, address _upline) private {
        if(users[_addr].upline == address(0) && _upline != _addr && _addr != owner && (users[_upline].deposit_time > 0 || _upline == owner)) {
            users[_addr].upline = _upline;
            users[_upline].referrals++;

            emit Upline(_addr, _upline);
            total_users++;

            for(uint8 i = 0; i < ref_bonuses.length; i++) {
                if(_upline == address(0)) break;

                users[_upline].total_structure++; // увеличение структуры пригласившего

                _upline = users[_upline].upline;
            }
        }
    }


    function _deposit(address _addr, uint256 _amount) private {
        require(users[_addr].upline != address(0) || _addr == owner, "No upline");

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

        require(ref_bonuses.length <= availableLines, "Wordlex Status: Unavailable lines, please, update status");

        for(uint8 i = 0; i < ref_bonuses.length; i++) {
            if(up == address(0)) break; // не для админа

            if(users[up].referrals >= i + 1) {
                uint256 bonus = _amount * ref_bonuses[i] / 1000; // 0,4% every line

                users[up].match_bonus += bonus;

                emit MatchPayout(up, _addr, bonus);
            }
            up = users[up].upline;
        }
    }


    function maxDailyPayoutOf(address _statusHolder) pure public returns(uint256) {
        (, uint256 _dailyLimit, , ) = IWordlexStatus.getStatusMeta(IWordlexStatus.getAddressStatus(_statusHolder));
        return _dailyLimit;
    }


    function payoutOf(address _addr) view external returns(uint256 payout, uint256 max_payout) {
        max_payout = this.maxDailyPayoutOf(_addr);

        if(users[_addr].deposit_payouts < max_payout) {

            payout = (users[_addr].deposit_amount * ((block.timestamp - users[_addr].deposit_time) / 1 days)*getDailyPercent(_addr) / 1000) - users[_addr].deposit_payouts;

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
                                                        uint256 timeOfCarSell,
                                                        bool statusOfCar) {
        return (users[_addr].upline,
                users[_addr].deposit_time,
                users[_addr].deposit_amount,
                users[_addr].payouts,
                users[_addr].match_bonus,
                users[_addr].timeOfCarSell,
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


    function createCarStatus(address _addr) public {
        require(msg.sender == owner);
        users[_addr].timeOfCarSell = block.timestamp;
    }


   // function setCarStatus() public {
   //     require(msg.sender == owner);
   //     users[_addr].statusOfCar = true;
   // }

   // function setCarPrice(uint256 _newCarPriceInWDX) public {
   //     require(msg.sender == owner);
   //     carPriceInWDX = _newCarPriceInWDX;
   // }

}