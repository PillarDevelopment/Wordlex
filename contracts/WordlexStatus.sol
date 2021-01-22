// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.8.0;

import "./IPriceController.sol";
import "./Ownable.sol";
import "./SafeMath.sol";

contract WordlexStatus is Ownable {
    using SafeMath for uint256;

    struct Status {
        uint256 usdPrice;
        uint256 weeklyLimitUSD;
        uint256 lines;
        string name;
    }

    struct User {
        uint256 status;
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

    Status[] internal statuses;

    IPriceController public controller;

    uint8[] public ref_bonuses;

    uint256 public total_users = 1;
    uint256 public total_deposited;
    uint256 public total_withdraw;

    mapping(address => User) public users;

    address payable public admin;

    event Upline(address indexed addr, address indexed upline);
    event MatchPayout(address indexed addr, address indexed from, uint256 amount);


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

        admin = _admin;
        users[msg.sender].status == 7;
    }


    function buyStatus(uint256 _id, address payable _up_liner) public payable {

        require(msg.value == getStatusPrice(_id), "Bad Amount");
        require(users[msg.sender].status == 0, "Status already bought, please, upgrade");
        require(_up_liner != address(0) && users[_up_liner].status > 0, "Upliner doesn't exist");

        uint256 upliner_bonus = msg.value.div(20);
        _up_liner.transfer(upliner_bonus);
        admin.transfer(msg.value.sub(upliner_bonus));
        _setUpline(msg.sender, _up_liner);
        users[msg.sender].status == _id;
    }


    function upgradeStatus(uint256 _id) public payable {
        require(users[msg.sender].status > 0, "Status can't upgrade, please, buy");
        require(msg.value == getStatusPrice(_id).sub(getStatusPrice(users[msg.sender].status)), "Bad Amount");
        users[msg.sender].status == _id;
    }


    function addStatus( uint256 _usdPrice,
                        uint256 _weeklyLimitUSD,
                        uint256 _lines,
                        string memory _name) public onlyOwner {
        statuses.push(Status({usdPrice:_usdPrice, weeklyLimitUSD:_weeklyLimitUSD, lines:_lines, name:_name}));
    }


    function getStatusPrice(uint256 _id) public view returns(uint256) {
        return statuses[_id].usdPrice.mul(controller.getCurrentUsdRate());
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
        require(msg.sender == admin);
        admin = _newAdmin;
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

    function _refPayout(address _addr, uint256 _amount) private {
        address up = users[_addr].upline;
        require(ref_bonuses.length <= getAddressStatus(_addr), "Wordlex Status: Unavailable lines, please, update status");

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

    function withdraw() public {
        (uint256 to_payout, uint256 max_payout) = this.payoutOf(msg.sender);

        require(users[msg.sender].payouts < max_payout, "Full payouts");
        if(to_payout > 0) {
            if(users[msg.sender].payouts.add(to_payout) > max_payout) {
                to_payout = max_payout.sub(users[msg.sender].payouts);
            }

            users[msg.sender].deposit_payouts += to_payout;
            users[msg.sender].payouts += to_payout;

            _refPayout(msg.sender, to_payout);
        }


        if(users[msg.sender].payouts < max_payout && users[msg.sender].direct_bonus > 0) {
            uint256 direct_bonus = users[msg.sender].direct_bonus;

            if(users[msg.sender].payouts.add(direct_bonus) > max_payout) {
                direct_bonus = max_payout.sub(users[msg.sender].payouts);
            }

            users[msg.sender].direct_bonus -= direct_bonus;
            users[msg.sender].payouts += direct_bonus;
            to_payout += direct_bonus;
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

        require(to_payout > 0, "Zero payout");

        users[msg.sender].total_payouts += to_payout;
        total_withdraw += to_payout;

        msg.sender.transfer(to_payout);
    }

    function payoutOf(address _addr) view public returns(uint256 payout, uint256 max_payout) {
        max_payout = this.maxPayoutOf(_addr);

        if(users[_addr].deposit_payouts < max_payout) {
            payout = (users[_addr].deposit_amount.mul((block.timestamp.sub(users[_addr].deposit_time)).div(1 days)).div(100)).sub(users[_addr].deposit_payouts);

            if(users[_addr].deposit_payouts.add(payout) > max_payout) {
                payout = max_payout.sub(users[_addr].deposit_payouts);
            }
        }
    }

    function maxPayoutOf(address _addr) view public returns(uint256) {
        return users[_addr].direct_bonus.add(users[_addr].match_bonus).add(users[_addr].deposit_amount);
    }

}