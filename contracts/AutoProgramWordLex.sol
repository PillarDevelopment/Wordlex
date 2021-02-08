// SPDX-License-Identifier: MIT
pragma solidity ^0.5.8;

import "./ITRC20.sol";
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
        uint256 investAmount;
        uint40 investTime;
        uint256 totalStructure;
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
    mapping(address => bool) public liquidateUsers;

    uint256 public totalInvested;
    uint256 public totalWithdraw;

    event NewDeal(address indexed addr, uint256 amount);
    event Withdraw(address indexed addr, uint256 amount);
    event LiquidatedInactive(
        address indexed inactiveAccount,
        address indexed liquidator,
        uint256 amount
    );

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

    function registration(
        address _upline,
        uint256 _carPrice,
        address _addr
    ) public onlyOwner {
        require(
            !liquidateUsers[msg.sender],
            "AutoProgramWDX: This address liquidated"
        );
        _setUpline(_addr, _upline);
        users[_addr].carPrice = _carPrice;
        users[_addr].statusOfCar = false;
    }

    function acceptPaidForCar(address _buyer) public onlyOwner {
        WDXToken.transfer(owner(), users[_buyer].investAmount);
        users[_buyer].investAmount = 0;
    }

    function setUserCarPrice(address _addr, uint256 _newCarPrice)
        public
        onlyOwner
    {
        require(_newCarPrice != 0, "AutoProgramWDX: Unavailable price");
        users[_addr].carPrice = _newCarPrice;
    }

    function setRefBonusesPercentage(uint256 line, uint8 newAmount) public {
        require(refBonuses.length > line, "AutoProgramWDX:unavailable line");
        refBonuses[line] = newAmount;
    }

    function buyCar(uint256 _amount) public {
        require(
            !liquidateUsers[msg.sender],
            "AutoProgramWDX: This address liquidated"
        );

        require(
            _amount == users[msg.sender].carPrice &&
                users[msg.sender].carPrice != 0,
            "AutoProgramWDX: Invalid amount or carPrice isn't determined"
        );

        require(
            users[msg.sender].upLine != address(0x0),
            "AutoProgramWDX: Address not registered"
        );

        _invest(msg.sender, _amount);
        WDXToken.transferFrom(msg.sender, address(this), _amount);
        users[msg.sender].statusOfCar = true;
    }

    function checkThreeComrades(
        address _first,
        address _second,
        address _third
    ) public {
        require(
            users[_first].carPrice == users[msg.sender].carPrice,
            "AutoProgramWDX:Incorrect Price to 1 comrade"
        );
        require(
            users[_second].carPrice == users[msg.sender].carPrice,
            "AutoProgramWDX:Incorrect Price to 2 comrade"
        );
        require(
            users[_third].carPrice == users[msg.sender].carPrice,
            "AutoProgramWDX:Incorrect Price to 3 comrade"
        );

        users[msg.sender].licence = true;
    }

    function withdraw() public {
        require(
            users[msg.sender].activeAccount ||
                (users[msg.sender].investTime.add(180 days) < block.timestamp &&
                    getsBuyersIn1Line(msg.sender) > 1),
            "AutoProgramWDX: You need to buy a car or your referrals need buy a car"
        );

        _refPayout(msg.sender, users[msg.sender].carPrice);
        uint256 match_bonus = users[msg.sender].match_bonus;

        users[msg.sender].match_bonus = 0;
        uint256 currentWithdraw =
            match_bonus.add(users[msg.sender].direct_bonus);
        users[msg.sender].payouts = users[msg.sender].payouts.add(
            currentWithdraw
        );
        totalWithdraw += totalWithdraw.add(currentWithdraw);
        users[msg.sender].direct_bonus = 0;
        WDXToken.transfer(msg.sender, currentWithdraw);
        emit Withdraw(msg.sender, currentWithdraw);
    }

    function checkActiveStatus() public {
        require(
            !users[msg.sender].activeAccount,
            "AutoProgramWDX: Account already active"
        );
        if (users[msg.sender].statusOfCar) {
            users[msg.sender].activeAccount = true;
        } else {
            for (
                uint256 i = 0;
                i < users[msg.sender].firstLineIds.length;
                i++
            ) {
                uint8 carBuyers;
                if (users[ids[users[msg.sender].firstLineIds[i]]].statusOfCar) {
                    // член 1й линии купил машину
                    carBuyers++;
                }
                if (carBuyers >= 2) {
                    users[msg.sender].activeAccount = true;
                    break;
                }
            }
        }
    }

    function liquidateInactiveAccount(address inactiveAccount) external {
        require(
            liquidateUsers[msg.sender] == false,
            "AutoProgramWDX: This address liquidated"
        );
        require(
            users[msg.sender].statusOfCar == true,
            "AutoProgramWDX: Sender is not Active Account"
        );
        require(
            users[inactiveAccount].statusOfCar == false ||
                users[inactiveAccount].totalStructure == 0,
            "AutoProgramWDX: This address bought a car"
        );

        require(
            users[inactiveAccount].investTime.add(180 days) < now,
            "AutoProgramWDX: Need more time"
        );
        require(
            users[inactiveAccount].carPrice != 0,
            "AutoProgramWDX: This address isn't inactive or not available"
        );

        _refPayout(inactiveAccount, users[inactiveAccount].carPrice);
        uint256 liquidationAmount =
            users[inactiveAccount].match_bonus.add(
                users[inactiveAccount].direct_bonus
            );
        liquidateUsers[inactiveAccount] = true;
        users[inactiveAccount].direct_bonus = 0;

        WDXToken.transfer(msg.sender, liquidationAmount);
        emit LiquidatedInactive(inactiveAccount, msg.sender, liquidationAmount);
    }

    function getsBuyersIn1Line(address _addr)
        public
        view
        returns (uint256 counter)
    {
        for (uint256 i = 0; i < users[_addr].firstLineIds.length; i++) {
            if (users[ids[users[_addr].firstLineIds[i]]].statusOfCar) {
                counter++;
            }
        }
    }

    function getAddressFirstLine(address _addr)
        public
        view
        returns (uint256[] memory)
    {
        return users[_addr].firstLineIds;
    }

    function getTotalUsers() public view returns (uint256) {
        return ids.length;
    }

    function _setUpline(address _addr, address _upLine) internal {
        if (_upLine != _addr) {
            users[_addr].upLine = _upLine;
            users[_upLine].referrals++;

            ids.push(_addr);
            users[_upLine].firstLineIds.push(ids.length.sub(1));

            for (uint8 i = 0; i < refBonuses.length; i++) {
                if (_upLine == address(0)) break;
                users[_upLine].totalStructure++;
                _upLine = users[_upLine].upLine;
            }
        }
    }

    function _invest(address _addr, uint256 _amount) internal {
        require(
            users[_addr].upLine != address(0) || _addr == owner(),
            "AutoProgramWDX: No upLine"
        );

        users[_addr].investAmount = users[_addr].investAmount.add(_amount);
        if (users[_addr].investTime == 0) {
            users[_addr].investTime = uint40(block.timestamp);
        }
        totalInvested = totalInvested.add(_amount);
        emit NewDeal(_addr, _amount);

        if (users[_addr].upLine != address(0)) {
            users[users[_addr].upLine].direct_bonus += _amount.mul(3).div(100);
        }
    }

    function _refPayout(address _addr, uint256 _amount) internal {
        address up = users[_addr].upLine;

        for (
            uint8 i = 0;
            i <
            statusContract.getStatusLines(
                statusContract.getAddressStatus(_addr)
            );
            i++
        ) {
            if (users[up].referrals >= i + 1) {
                uint256 bonus = _amount.mul(refBonuses[i].div(1000));
                users[up].match_bonus += bonus;
            }
            up = users[up].upLine;
        }
    }
}
