// SPDX-License-Identifier: MIT
pragma solidity ^0.5.8;

import "./IPriceController.sol";
import "./Ownable.sol";
import "./SafeMath.sol";

contract WordLexStatus is Ownable {
    using SafeMath for uint256;

    struct Status {
        uint256 usdPrice;
        uint256 weeklyLimitUSD;
        uint256 lines;
        string name;
    }

    struct User {
        uint40 depositTime;
        uint40 currentDirectUsers;
        uint40 status;
        uint256 referrals;
        uint256 payouts;
        uint256 directBonus;
        uint256 matchBonus;
        uint256 totalStructure;
        address upline;
    }

    Status[] internal statuses;

    IPriceController public controller;

    uint8[] public refBonuses;

    uint256 public totalUsers = 1;
    uint256 public totalWithdraw;

    mapping(address => User) public users;

    address payable public admin;

    event Upline(address indexed addr, address indexed upline);
    event MatchPayout(address indexed addr, address indexed from, uint256 amount);
    event DirectPayout(address indexed addr, address indexed from, uint256 amount);

    constructor(address _priceController, address payable _admin) public {
        controller = IPriceController(_priceController);
        statuses.push(Status({usdPrice:0, weeklyLimitUSD:0, lines:0, name:"Without Status"}));
        statuses.push(Status({usdPrice:10, weeklyLimitUSD:5, lines:1, name:"Test Drive"}));
        statuses.push(Status({usdPrice:100, weeklyLimitUSD:50, lines:2, name:"Bronze"}));
        statuses.push(Status({usdPrice:300, weeklyLimitUSD:150, lines:3, name:"Silver"}));
        statuses.push(Status({usdPrice:1000, weeklyLimitUSD:500, lines:5, name:"Gold"}));
        statuses.push(Status({usdPrice:3000, weeklyLimitUSD:1500, lines:7, name:"Platinum"}));
        statuses.push(Status({usdPrice:6000, weeklyLimitUSD:3000, lines:8, name:"Status"}));
        statuses.push(Status({usdPrice:10000, weeklyLimitUSD:5000, lines:10, name:"Brilliant"}));

        refBonuses.push(5);
        refBonuses.push(5);
        refBonuses.push(5);
        refBonuses.push(5);
        refBonuses.push(5);
        refBonuses.push(5);
        refBonuses.push(5);
        refBonuses.push(5);
        refBonuses.push(5);
        refBonuses.push(5);

        admin = _admin;
        users[admin].status = 7;
        _setUpline(admin, address(0x0));
    }


    function buyStatus(uint40 _id, address payable _upLiner) public payable {

        require(msg.value == getStatusPrice(_id), "WDXStatus:Bad Amount");
        require(users[msg.sender].status == 0, "WDXStatus:Status already bought");
        require(_upLiner != address(0) && users[_upLiner].status > 0, "WDXStatus: UpLiner doesn't exist");

        users[msg.sender].status = _id;
        _setUpline(msg.sender, _upLiner);
        users[msg.sender].depositTime = uint40(block.timestamp);

        if(_upLiner != address(0)) {
            users[_upLiner].directBonus = users[_upLiner].directBonus.add(msg.value.mul(5).div(100));
            emit DirectPayout(_upLiner, msg.sender, msg.value.mul(5).div(100));
            users[_upLiner].currentDirectUsers++;

            if (users[_upLiner].currentDirectUsers == 10) {
                users[_upLiner].currentDirectUsers = 0;
                uint256 directBonus = users[_upLiner].directBonus;
                users[_upLiner].directBonus = 0;
                _upLiner.transfer(directBonus);
            }
        }
    }


    function upgradeStatus(uint40 _id) public payable {
        require(users[msg.sender].status > 0, "WDXStatus:Need buy Status");
        require(users[msg.sender].status < _id, "WDXStatus:Invalid id");
        require(msg.value == getStatusPrice(_id).sub(getStatusPrice(users[msg.sender].status)), "WDXStatus:Bad Amount");
        users[msg.sender].status = _id;
    }


    function addStatus( uint256 _usdPrice,
                        uint256 _weeklyLimitUSD,
                        uint256 _lines,
                        string memory _name) public onlyOwner {
        statuses.push(Status({usdPrice:_usdPrice, weeklyLimitUSD:_weeklyLimitUSD, lines:_lines, name:_name}));
    }


    function getStatusPrice(uint256 _statusId) public view returns(uint256) {
        return statuses[_statusId].usdPrice.mul(controller.getCurrentUsdRate());
    }


    function getAddressStatus(address _statusHolder) public view returns(uint256) {
        return users[_statusHolder].status;
    }


    function getStatusUSDPrice(uint256 _statusId) external view returns(uint256) {
        return statuses[_statusId].usdPrice;
    }


    function getStatusLimit(uint256 _statusId) external view returns(uint256) {
        return statuses[_statusId].weeklyLimitUSD.mul(controller.getCurrentUsdRate());
    }


    function getStatusLines(uint256 _statusId) external view returns(uint256) {
        return statuses[_statusId].lines;
    }


    function getStatusName(uint256 _statusId) external view returns(string memory) {
        return statuses[_statusId].name;
    }


    function setAdminAddress(address payable _newAdmin) public {
        require(msg.sender == owner(), "WDXStatus:Sender isn't owner");
        admin = _newAdmin;
    }


    function withdraw() public {
        uint256 toPayout = users[msg.sender].matchBonus;

        users[msg.sender].payouts += toPayout;
        totalWithdraw += toPayout;
        users[msg.sender].matchBonus = 0;

        _refPayout(msg.sender, toPayout);
        msg.sender.transfer(toPayout);
    }


    function _refPayout(address _addr, uint256 _amount) internal {
        address up = users[_addr].upline;
        require(refBonuses.length <= getAddressStatus(_addr), "WDXStatus:Unavailable lines");

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


    function _setUpline(address _addr, address _upline) internal {
        if(users[_addr].upline == address(0) && _upline != _addr && _addr != owner() && (users[_upline].depositTime > 0 || _upline == owner())) {

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


    function setRefBonusesPercentage(uint256 line, uint8 newAmount) public {
        require(msg.sender == admin, "WDXStatus:address isn't admin");
        require(refBonuses.length > line, "WDXStatus:unavailable line");
        refBonuses[line] = newAmount;
    }

}