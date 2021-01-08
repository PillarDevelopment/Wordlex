pragma solidity ^0.5.12;

interface IWordlexStatus {

    function getStatusPrice(uint256 _id) external view returns(uint256);

    function getAddressStatus(address _statusHolder) external view returns(uint256);

    function getStatusMeta(uint256 _statusId) external view returns(uint256 _usdPrice, uint256 _weeklyLimitUSD, uint256 _lines, string memory _name);

}