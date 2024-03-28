//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../interfaces/IFactory.sol";
import "../interfaces/IExchange.sol";

contract Exchange is ERC20 {
    IERC20 token;
    IFactory factory;

    event TokenPurchase(
        address indexed buyer,
        uint256 indexed eth_sold,
        uint256 indexed tokens_bought
    );
    event EthPurchase(
        address indexed buyer,
        uint256 indexed tokens_sold,
        uint256 indexed eth_bought
    );
    event AddLiquidity(
        address indexed provider,
        uint256 indexed eth_amount,
        uint256 indexed token_amount
    );
    event RemoveLiquidity(
        address indexed provider,
        uint256 indexed eth_amount,
        uint256 indexed token_amount
    );

    constructor(address _token) ERC20("Gray Uniswap V2", "GUNI-V2") {
        token = IERC20(_token);
        factory = IFactory(msg.sender);
    }

    // 유동성 공급
    function addLiquidity(uint256 _maxTokens) public payable {
        uint256 totalLiquidity = totalSupply();
        // 유동성이 공급이 된 경우 추가로 공급할때
        if (totalLiquidity > 0) {
            uint256 ethReserve = address(this).balance - msg.value;
            uint256 tokenReserve = token.balanceOf(address(this));
            uint256 tokenAmount = msg.value * (tokenReserve / ethReserve);
            require(_maxTokens >= tokenAmount);
            token.transferFrom(msg.sender, address(this), tokenAmount);
            uint256 liquidityMinted = totalLiquidity * (msg.value / ethReserve);
            _mint(msg.sender, liquidityMinted);
            // 유동성이 0 일때
        } else {
            uint256 tokenAmount = _maxTokens;
            uint256 initialLiquidity = address(this).balance;
            // LP 토큰 민팅
            _mint(msg.sender, initialLiquidity);

            token.transferFrom(msg.sender, address(this), tokenAmount);
        }
    }

    // 유동성 제거
    function removeLiquidity(uint256 _lpTokenAmount) public {
        require(_lpTokenAmount > 0);
        uint256 totalLiquidity = totalSupply();
        uint256 ethAmount = _lpTokenAmount *
            (address(this).balance / totalLiquidity);
        uint256 tokenAmount = ((_lpTokenAmount *
            (token.balanceOf(address(this)))) / totalLiquidity);

        _burn(msg.sender, _lpTokenAmount);

        payable(msg.sender).transfer(ethAmount);
        token.transfer(msg.sender, tokenAmount);
    }

    // outputToken 가격측정, 수수료 적용 전
    function getOutputAmount(
        uint256 inputAmount,
        uint inputReserve,
        uint256 outputReserve
    ) public pure returns (uint256) {
        uint256 numerator = outputReserve * inputAmount;
        uint256 denominator = inputReserve + inputAmount;
        return numerator / denominator;
    }

    // outputToken 가격측정, 수수료 적용 후
    function getOutputAmountWithFee(
        uint256 inputAmount,
        uint inputReserve,
        uint256 outputReserve
    ) public pure returns (uint256) {
        uint256 inputAmountWithFee = inputAmount * 99;
        uint256 numerator = outputReserve * inputAmountWithFee;
        uint256 denominator = inputReserve * 100 + inputAmountWithFee;
        return numerator / denominator;
    }

    // ETH -> ERC20으로 Swap
    //                    프론트에서 슬리피지가 계산되어 입력
    function ethToTokenSwap(uint256 _minTokens) public payable {
        ethToToken(_minTokens, msg.sender);
    }

    // ETH -> ERC20으로 Swap
    function ethToTokenTransfer(
        uint256 _minTokens,
        address _recipient
    ) public payable {
        require(_recipient != address(0));
        ethToToken(_minTokens, _recipient);
    }

    // ERC20 -> ETH으로 Swap
    function tokenToEthSwap(
        uint256 _tokenSold,
        uint256 _minEth
    ) public payable {
        uint256 outputAmount = getOutputAmountWithFee(
            _tokenSold,
            token.balanceOf(address(this)),
            address(this).balance
        );

        require(outputAmount >= _minEth, "Insufficient outputamount");

        token.transferFrom(msg.sender, address(this), _tokenSold);
        payable(msg.sender).transfer(outputAmount);
    }

    // ERC20 -> ETH -> ERC20으로 Swap
    function tokenToTokenSwap(
        uint256 _tokenSold,
        uint256 _minTokenBought,
        uint256 _minEthBought,
        address _tokenAddress
    ) public payable {
        address toTokenExchangeAddress = factory.getExchange(_tokenAddress);
        uint256 ethOutputAmount = getOutputAmountWithFee(
            _tokenSold,
            token.balanceOf(address(this)),
            address(this).balance
        );

        require(outputAmount >= _minEthBought, "Insufficient outputamount");

        token.transferFrom(msg.sender, address(this), _tokenSold);

        // 새로운 인터페이스
        IExchange(toTokenExchangeAddress).ethToTokenTransfer{
            value: ethOutputAmount
        }(_minTokenBought, msg.sender);
    }

    function ethToToken(uint _minTokens, address _recipient) private {
        uint256 outputAmount = getOutputAmountWithFee(
            msg.value,
            // ethToTokenSwap 함수가 실행 될 때 이미 ETH가 Exchange Contract로 넘왔기 때문에 넘어오기 전에 풀에 있던 ETH 개수를 가져오기 위해서다.
            address(this).balance - msg.value,
            token.balanceOf(address(this))
        );

        require(outputAmount >= _minTokens, "Insufficient outputamount");

        IERC20(token).transfer(_recipient, outputAmount);
    }
}
