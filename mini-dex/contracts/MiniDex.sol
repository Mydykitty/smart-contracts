// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(
        address from,
        address to,
        uint amount
    ) external returns (bool);

    function transfer(address to, uint amount) external returns (bool);
}

contract MiniDex {
    IERC20 public token;

    constructor(address _token) {
        token = IERC20(_token);
    }

    // ================= 内部余额 =================
    mapping(address => uint) public ethBalance;
    mapping(address => uint) public tokenBalance;

    // ================= Events =================
    event OrderPlaced(
        uint indexed orderId,
        address indexed trader,
        bool isBuy,
        uint tokenAmount,
        uint ethAmount
    );

    event OrderFilled(
        uint indexed orderId,
        address indexed maker,
        address indexed taker
    );

    event OrderCancelled(uint indexed orderId, address indexed trader);

    // ================= 订单 =================
    struct Order {
        address trader; // 挂单人（maker）
        uint tokenAmount; // token 数量
        uint ethAmount; // eth 数量
        bool isBuy; // true = 买单，false = 卖单
        bool filled; // 是否已成交 / 撤单
    }

    Order[] public orders;

    // ================= 充值 =================
    function depositETH() external payable {
        ethBalance[msg.sender] += msg.value;
    }

    receive() external payable {
        ethBalance[msg.sender] += msg.value;
    }

    function depositToken(uint amount) external {
        require(
            token.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );
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
    // ⚠️ 不锁资产，只是报价
    function placeOrder(uint tokenAmount, uint ethAmount, bool isBuy) external {
        require(tokenAmount > 0 && ethAmount > 0, "Invalid amount");

        orders.push(
            Order({
                trader: msg.sender,
                tokenAmount: tokenAmount,
                ethAmount: ethAmount,
                isBuy: isBuy,
                filled: false
            })
        );

        uint orderId = orders.length - 1;

        emit OrderPlaced(orderId, msg.sender, isBuy, tokenAmount, ethAmount);
    }

    // ================= 成交 =================
    function fillOrder(uint orderId) external {
        require(orderId < orders.length, "Invalid order");

        Order storage order = orders[orderId];
        require(!order.filled, "Order filled");
        require(order.trader != msg.sender, "Self trade");

        if (order.isBuy) {
            /**
             * 买单：
             * - maker（挂单人）用 ETH 买 Token
             * - taker（吃单人）卖 Token
             */

            // taker 必须有 Token
            require(
                tokenBalance[msg.sender] >= order.tokenAmount,
                "Not enough token"
            );

            // maker 必须有 ETH
            require(
                ethBalance[order.trader] >= order.ethAmount,
                "Buyer has no ETH"
            );

            // Token -> 买家
            tokenBalance[msg.sender] -= order.tokenAmount;
            tokenBalance[order.trader] += order.tokenAmount;

            // ETH -> 卖家
            ethBalance[order.trader] -= order.ethAmount;
            ethBalance[msg.sender] += order.ethAmount;
        } else {
            /**
             * 卖单：
             * - maker（挂单人）卖 Token
             * - taker（吃单人）用 ETH 买 Token
             */

            // maker 必须有 Token
            require(
                tokenBalance[order.trader] >= order.tokenAmount,
                "Seller has no token"
            );

            // taker 必须有 ETH
            require(
                ethBalance[msg.sender] >= order.ethAmount,
                "Not enough ETH"
            );

            // ETH -> 卖家
            ethBalance[msg.sender] -= order.ethAmount;
            ethBalance[order.trader] += order.ethAmount;

            // Token -> 买家
            tokenBalance[order.trader] -= order.tokenAmount;
            tokenBalance[msg.sender] += order.tokenAmount;
        }

        order.filled = true;

        emit OrderFilled(
            orderId,
            order.trader, // maker
            msg.sender // taker
        );
    }

    // ================= 撤单 =================
    function cancelOrder(uint orderId) external {
        require(orderId < orders.length, "Invalid order");

        Order storage order = orders[orderId];
        require(order.trader == msg.sender, "Not your order");
        require(!order.filled, "Already filled");

        order.filled = true;

        emit OrderCancelled(orderId, msg.sender);
    }

    // ================= 查询 =================
    function getOrdersCount() external view returns (uint) {
        return orders.length;
    }
}
