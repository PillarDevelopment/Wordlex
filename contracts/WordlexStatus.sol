pragma solidity ^0.5.12;

library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () internal {
        address msgSender = msg.sender;
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Returns true if the caller is the current owner.
     */
    function isOwner() public view returns (bool) {
        return msg.sender == _owner;
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

interface IPriceController {

    function setPriceProvider(address _newPriceProvider) external;

    function updateUsdRate(uint256 _newRate) external;

    function getCurrentUsdRate() external view returns(uint256);
}

contract WordlexStatus is Ownable {
    using SafeMath for uint256;

    struct Status {
        uint256 usdPrice;
        uint256 weeklyLimitUSD;
        uint256 lines;
        string name;
    }

    Status[] internal statuses;

    IPriceController public controller;

    uint8[] public ref_bonuses;

    mapping(address => uint256) users;

    address payable public admin;

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
        users[msg.sender] == 7;
    }


    function buyStatus(uint256 _id, address payable _up_liner) public payable {

        require(msg.value == getStatusPrice(_id), "Bad Amount");
        require(users[msg.sender] == 0, "Status already bought, please, upgrade");
        require(_up_liner != address(0) && users[_up_liner] > 0, "Upliner doesn't exist");

        uint256 upliner_bonus = msg.value.div(20);
        _up_liner.transfer(upliner_bonus);
        admin.transfer(msg.value.sub(upliner_bonus));

        users[msg.sender] == _id;
    }


    function upgradeStatus(uint256 _id) public payable {
        require(users[msg.sender] > 0, "Status can't upgrade, please, buy");
        require(msg.value == getStatusPrice(_id).sub(getStatusPrice(users[msg.sender])), "Bad Amount");
        users[msg.sender] == _id;
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


    function getAddressStatus(address _statusHolder) external view returns(uint256) {
        return users[_statusHolder];
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


    function setAdminAddress(address _newAdmin) public {
        require(msg.sender == admin);
        admin = _newAdmin;
    }

    function _setUpline(address _addr, address _upline) private {
        if(users[_addr].upline == address(0) && _upline != _addr && _addr != owner && (users[_upline].deposit_time > 0 || _upline == owner)) {
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
                uint256 bonus = _amount * ref_bonuses[i] / 100;

                users[up].match_bonus += bonus;

                emit MatchPayout(up, _addr, bonus);
            }
            up = users[up].upline;
        }
    }

}