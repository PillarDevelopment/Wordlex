// SPDX-License-Identifier: MIT
pragma solidity ^0.5.8;

import  "./ITRC20.sol";
import "./IWordLexStatus.sol";
import "./Ownable.sol";
import "./SafeMath.sol";

contract AutoProgramWordLex is Ownable {
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
        uint40 deposit_time;
        uint256 total_structure;
        uint256 carPrice;
        bool statusOfCar;
        bool activeAccount;
        bool licence;
        uint256[] firstLineIds;
    }

    ITRC20 public WDXToken;
    IWordLexStatus public statusContract;

    mapping(address => User) public users;
    address[] public ids;
    uint8[] public refBonuses;

    uint256 public totalUsers = 1;
    uint256 public totalDeposited;
    uint256 public totalWithdraw;

    event Upline(address indexed addr, address indexed upline);
    event NewDeposit(address indexed addr, uint256 amount);
    event DirectPayout(address indexed addr, address indexed from, uint256 amount);
    event MatchPayout(address indexed addr, address indexed from, uint256 amount);
    event Withdraw(address indexed addr, uint256 amount);
    event LimitReached(address indexed addr, uint256 amount);
    event LiquidatedInactive(address indexed inactiveAccount, address indexed liquidator, uint256 amount);

    constructor(ITRC20 _wdxToken, IWordLexStatus _statusContract) public {
        WDXToken = _wdxToken;
        statusContract = _statusContract;

        refBonuses.push(4); // 0,4
        refBonuses.push(4); // 0,4
        refBonuses.push(4); // 0,4
        refBonuses.push(4); // 0,4
        refBonuses.push(4); // 0,4
        refBonuses.push(4); // 0,4
        refBonuses.push(4); // 0,4
        refBonuses.push(4); // 0,4
        refBonuses.push(4); // 0,4
        refBonuses.push(4); // 0,4
    }


    /**
     ###################################################################################
     ##############################  External          #################################
     ###################################################################################
     */
    function buyCar(uint256 _amount)  public {

        require(_amount == users[msg.sender].carPrice && users[msg.sender].carPrice != 0,
                    "AutoProgramWDX: Invalid amount or carPrice isn't determined");
        require(users[msg.sender].upLine != address(0x0), "AutoProgramWDX: Address not registered");
        _deposit(msg.sender, _amount);
        WDXToken.transferFrom(msg.sender, address(this), _amount);
        users[msg.sender].statusOfCar = true;
    }


    function registration(address _upline, uint256 _carPrice, address _addr) public onlyOwner {
        _setUpline(_addr, _upline);
        users[_addr].carPrice = _carPrice;
        users[_addr].statusOfCar = false;
    }


    function withdraw() public {
        require(users[msg.sender].activeAccount ||
            (users[msg.sender].deposit_time.add(180 days) < block.timestamp && getsBuyersIn1Line(msg.sender) > 1),
               "AutoProgramWDX: You need to buy a car or your referrals need buy a car");

        _refPayout(msg.sender, users[msg.sender].deposit_amount);
        uint256 match_bonus = users[msg.sender].match_bonus;

        users[msg.sender].match_bonus = 0;
        uint256 currentWithdraw = match_bonus.add(users[msg.sender].deposit_amount);
        users[msg.sender].payouts = users[msg.sender].payouts.add(currentWithdraw);
        totalWithdraw += totalWithdraw.add(currentWithdraw);
        users[msg.sender].deposit_amount = 0;
        WDXToken.transfer(msg.sender, currentWithdraw);
        emit Withdraw(msg.sender, currentWithdraw);
    }


    function checkActiveStatus() public {
        require(!users[msg.sender].activeAccount, "AutoProgramWDX: Account already active");
        if (users[msg.sender].statusOfCar) {
            users[msg.sender].activeAccount = true;
        } else {
            for(uint i = 0; i < users[msg.sender].firstLineIds.length; i++) {
                uint8 carBuyers;
                if (users[ids[users[msg.sender].firstLineIds[i]]].statusOfCar) { // член 1й линии купил машину
                    carBuyers++;
                }
                if(carBuyers >= 2) {
                    users[msg.sender].activeAccount = true;
                    break;
                }
            }
        }
    }


    function checkThreeComrades(address _first, address _second, address _third) public {
        require(users[_first].carPrice == users[msg.sender].carPrice,"AutoProgramWDX:Incorrect Price to 1 comrade");
        require(users[_second].carPrice == users[msg.sender].carPrice,"AutoProgramWDX:Incorrect Price to 2 comrade");
        require(users[_third].carPrice == users[msg.sender].carPrice,"AutoProgramWDX:Incorrect Price to 3 comrade");

        users[msg.sender].licence = true;
    }


    function liquidateInactiveAccount(address inactiveAccount) external {
        require(users[msg.sender].statusOfCar == true, "AutoProgramWDX: Sender is not Active Account");
        require(users[inactiveAccount].statusOfCar == false, "AutoProgramWDX: This address bought a car");
        require(users[inactiveAccount].total_structure == 0, "AutoProgramWDX: This address have a structure");
        require(users[inactiveAccount].deposit_time.add(180 days) < now, "AutoProgramWDX: Need more time");
        require(users[inactiveAccount].deposit_amount != 0,
                "AutoProgramWDX: This address isn't inactive or not available");

        uint256 liquidationAmount = users[inactiveAccount].deposit_amount;
        users[inactiveAccount].deposit_amount = 0;
        WDXToken.transfer(msg.sender, liquidationAmount);
        emit LiquidatedInactive(inactiveAccount, msg.sender, liquidationAmount);
    }


    function _setUpline(address _addr, address _upLine) internal {
        if(users[_addr].upLine == address(0) && _upLine != _addr && _addr != owner()
                && (users[_upLine].deposit_time > 0 || _upLine == owner())) {

            users[_addr].upLine = _upLine;
            users[_upLine].referrals++;

            emit Upline(_addr, _upLine);
            totalUsers++;
            ids.push(_addr);
            users[_upLine].firstLineIds.push(ids.length);

            for(uint8 i = 0; i < refBonuses.length; i++) {
                if(_upLine == address(0)) break;
                users[_upLine].total_structure++;
                _upLine = users[_upLine].upLine;
            }
        }
    }


    function _deposit(address _addr, uint256 _amount) internal {
        require(users[_addr].upLine != address(0) || _addr == owner(), "AutoProgramWDX: No upLine");

        users[_addr].deposit_amount = users[_addr].deposit_amount.add(_amount);
        if (users[_addr].deposit_time == 0) {
            users[_addr].deposit_time = uint40(block.timestamp);
        }

        totalDeposited = totalDeposited.add(_amount);
        emit NewDeposit(_addr, _amount);

        if(users[_addr].upLine != address(0) ) {
            users[users[_addr].upLine].direct_bonus += _amount.mul(3).div(100);
            emit DirectPayout(users[_addr].upLine, _addr, _amount.mul(3).div(100));
        }
    }


    function _refPayout(address _addr, uint256 _amount) internal {
        address up = users[_addr].upLine;

        for(uint8 i = 0; i < statusContract.getStatusLines(statusContract.getAddressStatus(_addr)); i++) {
            //if(up == address(0)) break;

            if(users[up].referrals >= i + 1) {
                uint256 bonus = _amount.mul(refBonuses[i].div(1000)); // 0,4% every line

                users[up].match_bonus += bonus;
                emit MatchPayout(up, _addr, bonus);
            }
            up = users[up].upLine;
        }
    }


    function contractInfo()public view returns(uint256 _totalUsers, uint256 _totalDeposited, uint256 _totalWithdraw) {
        return (totalUsers, totalDeposited, totalWithdraw);
    }


    function setUserCarPrice(address _addr, uint256 _newCarPrice) public onlyOwner {
        require(_newCarPrice != 0, "AutoProgramWDX: Unavailable price");
        users[_addr].carPrice = _newCarPrice;
    }


    function getsBuyersIn1Line(address _addr) public view returns(uint256 counter) {
        for(uint256 i = 0; i < users[_addr].firstLineIds.length; i++) {
            if (users[ids[users[_addr].firstLineIds[i]]].statusOfCar) {
                counter++;
            }
        }
    }

}