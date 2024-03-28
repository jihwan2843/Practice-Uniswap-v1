//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Exchange {
    IERC20 token;

    constructor(address _token) {
        token = IERC20(_token);
    }

    // transferFrom을 사용하는 이유는 토큰을 전송할때
    // Exchange contract에서 Token contract로 호출하기 때문에 transfer를
    // 사용할 때의 msg.sender는 Exchange contract가 되기 때문이다.
    function addLiquidity(uint256 _tokenAmount) public payable {
        token.transferFrom(msg.sender, address(this), _tokenAmount);
    }

    function ethToTokenSwap() public payable {
        uint256 inputAmount = msg.value;

        uint256 outputAmount = inputAmount;

        token.transfer(msg.sender, outputAmount);
    }

    function getPrice(
        uint256 inputReserve,
        uint256 outputReserve
    ) public pure returns (uint256) {
        uint256 numerator = inputReserve;
        uint256 denominator = outputReserve;
        return numerator / denominator;
    }
}
