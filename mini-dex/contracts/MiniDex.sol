// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address from, address to, uint amount) external returns (bool);
    function transfer(address to, uint amount) external returns (bool);
}

contract MiniDex {

    IERC20 public token;

    constructor(address _token) {
        token = IERC20(_token);
    }

    // 用户在交易所里的余额
    mapping(address => uint) public ethBalance;
    mapping(address => uint) public tokenBalance;

    struct Order {
        address trader;
        uint tokenAmount;
        uint ethAmount;
        bool isBuy;   // true = 买单, false = 卖单
        bool filled;
    }

    Order[] public orders;

    // ================= 充值 =================

    function depositETH() external payable {
        ethBalance[msg.sender] += msg.value;
    }

    // 允许直接向合约转 ETH 也计入余额
    receive() external payable {
        ethBalance[msg.sender] += msg.value;
    }

    function depositToken(uint amount) external {
        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        tokenBalance[msg.sender] += amount;
    }

    // ================= 提现 =================

    function withdrawETH(uint amount) external {
        require(ethBalance[msg.sender] >= amount, "Not enough ETH");
        ethBalance[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
    }

    function withdrawToken(uint amount) external {
        require(tokenBalance[msg.sender] >= amount, "Not enough token");
        tokenBalance[msg.sender] -= amount;
        require(token.transfer(msg.sender, amount), "Transfer failed");
    }

    // ================= 挂单 =================

    function placeOrder(uint tokenAmount, uint ethAmount, bool isBuy) external {
        if (isBuy) {
            require(ethBalance[msg.sender] >= ethAmount, "Not enough ETH");
        } else {
            require(tokenBalance[msg.sender] >= tokenAmount, "Not enough Token");
        }

        orders.push(Order(msg.sender, tokenAmount, ethAmount, isBuy, false));
    }

    // ================= 撮合成交 =================

    function fillOrder(uint orderId) external {
        Order storage order = orders[orderId];
        require(!order.filled, "Already filled");

        if (order.isBuy) {
            // 对方卖币给买家
            require(tokenBalance[msg.sender] >= order.tokenAmount, "Seller no token");

            tokenBalance[msg.sender] -= order.tokenAmount;
            tokenBalance[order.trader] += order.tokenAmount;

            ethBalance[order.trader] -= order.ethAmount;
            ethBalance[msg.sender] += order.ethAmount;

        } else {
            // 对方用 ETH 买币
            require(ethBalance[msg.sender] >= order.ethAmount, "Buyer no ETH");

            ethBalance[msg.sender] -= order.ethAmount;
            ethBalance[order.trader] += order.ethAmount;

            tokenBalance[order.trader] -= order.tokenAmount;
            tokenBalance[msg.sender] += order.tokenAmount;
        }

        order.filled = true;
    }

    // ================= 查询 =================

    function getOrdersCount() external view returns (uint) {
        return orders.length;
    }
}