//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IFactory {
    function getExchange(address _token) external view returns (address);
}
