// SPDX-License-Identifier: MIT
pragma solidity ^0.5.8;

interface IPriceController {
    function setPriceProvider(address _newPriceProvider) external;

    function updateUsdRate(uint256 _newRate) external;

    function getCurrentUsdRate() external view returns (uint256);
}
