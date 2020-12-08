pragma solidity 0.5.10;

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

contract WordlexStaking {

    struct User {
        uint256 cycle;
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
    }

    address payable public owner;
    IERC20 public WDX;

    mapping(address => User) public users;
    uint256[] public cycles;
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


    constructor(address payable _owner, IERC20 _wdx) public {
        owner = _owner;
        WDX = _wdx;


        // % который распределяют в линию, берется от прибыли вашего приглашенного.
        // Пример у вас на депозите 1000 WDX 2% в день это ваша прибыль = 20 WDX
        ref_bonuses.push(23);
        ref_bonuses.push(8);
        ref_bonuses.push(8);
        ref_bonuses.push(8);
        ref_bonuses.push(8);

        ref_bonuses.push(9);
        ref_bonuses.push(9);
        ref_bonuses.push(9);
        ref_bonuses.push(9);
        ref_bonuses.push(9);

        ref_bonuses.push(23);
        ref_bonuses.push(23);
        ref_bonuses.push(23);
        ref_bonuses.push(23);
        ref_bonuses.push(30);


        cycles.push(15e10);
        cycles.push(3e11);
        cycles.push(9e11);
        cycles.push(2e12);
    }


    function() payable external {
        _deposit(msg.sender, msg.value);
    }


    /**
     ###################################################################################
     ##############################  внешние методы #################################
     ###################################################################################
     */
    // функция депозита
    // Входите в Wordlex, внеся в фонд минимум 150 WDX.
    function deposit(address _upline) payable public {
        _setUpline(msg.sender, _upline);
        _deposit(msg.sender, msg.value);
    }


    // функция вывода
    function withdraw() public {
        (uint256 to_payout, uint256 max_payout) = this.payoutOf(msg.sender); // текущий депозит и макс вывод от депозита

        require(users[msg.sender].payouts < max_payout, "Full payouts"); // ывел весь депозит

        // Deposit payout
        if(to_payout > 0) {
            if(users[msg.sender].payouts + to_payout > max_payout) {
                to_payout = max_payout - users[msg.sender].payouts;
            }

            users[msg.sender].deposit_payouts += to_payout;
            users[msg.sender].payouts += to_payout;

            _refPayout(msg.sender, to_payout);
        }

        // Direct payout
        if(users[msg.sender].payouts < max_payout && users[msg.sender].direct_bonus > 0) {
            uint256 direct_bonus = users[msg.sender].direct_bonus;

            if(users[msg.sender].payouts + direct_bonus > max_payout) {
                direct_bonus = max_payout - users[msg.sender].payouts;
            }

            users[msg.sender].direct_bonus -= direct_bonus;
            users[msg.sender].payouts += direct_bonus;
            to_payout += direct_bonus;
        }


        // Match payout
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
    // изменение глубины линий
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


    // метод внесения депозита
    // проверяет доступный ввод исходя из возможного депозита по циклу
    // начисляет награду пригласившему - 10%
    function _deposit(address _addr, uint256 _amount) private {
        require(users[_addr].upline != address(0) || _addr == owner, "No upline");

        if(users[_addr].deposit_time > 0) {
            users[_addr].cycle++;

            require(users[_addr].payouts >= this.maxPayoutOf(users[_addr].deposit_amount), "Deposit already exists");
            require(_amount >= users[_addr].deposit_amount && _amount <= cycles[users[_addr].cycle > cycles.length - 1 ? cycles.length - 1 : users[_addr].cycle], "Bad amount");
        }
        else require(_amount >= 15e7 && _amount < 15e10  && _amount <= cycles[0], "Bad amount");

        users[_addr].payouts = 0;
        users[_addr].deposit_amount = _amount;
        users[_addr].deposit_payouts = 0;
        users[_addr].deposit_time = uint40(block.timestamp);
        users[_addr].total_deposits += _amount;

        total_deposited += _amount;

        emit NewDeposit(_addr, _amount);

        if(users[_addr].upline != address(0)) {
            users[users[_addr].upline].direct_bonus += _amount / 10; // 10% Прямая комиссия от вклада

            emit DirectPayout(users[_addr].upline, _addr, _amount / 10);
        }

    }


    // Ежедневные комиссионные, основанные на ежедневном доходе партнеров, для каждого прямого партнера активирован
    // 1 уровень, максимум 15 уровней, см. ниже
    function _refPayout(address _addr, uint256 _amount) private {
        address up = users[_addr].upline;

        for(uint8 i = 0; i < ref_bonuses.length; i++) {
            if(up == address(0)) break; // не для админа

            if(users[up].referrals >= i + 1) {
                uint256 bonus = _amount * ref_bonuses[i] / 100; // начисление бонуса комиссионого  (15 уровней)

                users[up].match_bonus += bonus; // здесь к участнику происхоит сумирование бонусов в соответствие с

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
    // Теперь вы имеете право получить обратно 300% от вашего ДЕПОЗИТА (пример: 1000 WDX на входе, 30 000 WDX на выходе).
    // 300% возврат возвращается 2 способа (пассивный и через маркетинг)
    function maxPayoutOf(uint256 _amount) pure public returns(uint256) {
        return _amount * 30 / 10; // 30% для изменения цикла
    }


    //возвращает текущий депозит и максимальный доход за вычетом выводов и наград для адреса
    function payoutOf(address _addr) view external returns(uint256 payout, uint256 max_payout) {
        max_payout = this.maxPayoutOf(users[_addr].deposit_amount);

        // 1% Ежедневная доходность вашего депозита (максимум 300 дней), 100% пассив.
        if(users[_addr].deposit_payouts < max_payout) {

            payout = (users[_addr].deposit_amount * ((block.timestamp - users[_addr].deposit_time) / 1 days) / 100) - users[_addr].deposit_payouts;

            if(users[_addr].deposit_payouts + payout > max_payout) {
                payout = max_payout - users[_addr].deposit_payouts;
            }
        }
    }


    // возвращает инфо по юзеру - аплайн время депозита размер депозита вывод прямой бонус матч бонус
    function userInfo(address _addr) view public returns(address upline, uint40 deposit_time, uint256 deposit_amount, uint256 payouts, uint256 direct_bonus, uint256 match_bonus) {
        return (users[_addr].upline, users[_addr].deposit_time, users[_addr].deposit_amount, users[_addr].payouts, users[_addr].direct_bonus, users[_addr].match_bonus);
    }


    // возвращает аггрегированную инфо по юзеру - количество рефералов депозитов выводов членов структуры
    function userInfoTotals(address _addr) view public returns(uint256 referrals, uint256 total_deposits, uint256 total_payouts, uint256 total_structure) {
        return (users[_addr].referrals, users[_addr].total_deposits, users[_addr].total_payouts, users[_addr].total_structure);
    }


    // Возвращает агрегированную инфо - все юзеров депозитов выводов
    function contractInfo() view public returns(uint256 _total_users, uint256 _total_deposited, uint256 _total_withdraw) {
        return (total_users, total_deposited, total_withdraw);
    }

}