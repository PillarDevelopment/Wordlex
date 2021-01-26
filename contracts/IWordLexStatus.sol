// SPDX-License-Identifier: MIT
pragma solidity ^0.5.8;

interface IWordLexStatus {

    function getStatusPrice(uint256 _statusId) external view returns(uint256);

    function getAddressStatus(address _statusHolder) external view returns(uint256);

    function getStatusLimit(uint256 _statusId) external view returns(uint256);

    function getStatusLines(uint256 _statusId) external view returns(uint256);

    function getStatusName(uint256 _statusId) external view returns(string memory);

    function getStatusUSDPrice(uint256 _statusId) external view returns(uint256);
}