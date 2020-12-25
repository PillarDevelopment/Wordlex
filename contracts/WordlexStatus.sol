pragma solidity ^0.5.12;

library SafeMath {

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

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

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
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

contract WordlexStatus {

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

    constructor(address _priceController) public {
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
    }

    function buyStatus(uint256 _id, address _up_liner) public payable {
        require(msg.value == getStatusPrice(_id), "Bad Amount");
        require(users[msg.sender] == 0, "Status already bought, please, upgrade");
        users[msg.sender] == _id;
    }

    function upgradeStatus() public payable {
        require(users[msg.sender] > 0, "Status can't upgrade, please, buy");
        require(msg.value == getStatusPrice(_id).sub(getStatusPrice(users[msg.sender])), "Bad Amount");
        users[msg.sender] == _id;
    }

    function addStatus(uint256 _usdPrice,
                       uint256 _weeklyLimitUSD,
                       uint256 _lines,
                       string _name) public onlyOwner {
        statuses.push(Status({usdPrice:_usdPrice, weeklyLimitUSD:_weeklyLimitUSD, lines:_lines, name:_name}));
    }


    function getStatusPrice(uint256 _id) public view returns(uint256) {
        return statuses[_id].mul(controller.getCurrentUsdRate());
    }


    function withdrawStatusAmount() public onlyOwner {
        owner.transfer(address(this).balance);
    }

}