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

    event OrderPartiallyFilled(
        uint indexed orderId,
        address indexed maker,
        address indexed taker,
        uint tokenFilled,
        uint ethFilled
    );

    event OrderFilled(uint indexed orderId, address indexed maker);

    event OrderCancelled(uint indexed orderId, address indexed trader);

    // ================= 订单 =================
    struct Order {
        address trader; // maker
        uint remainingToken; // 剩余 token
        uint remainingEth; // 剩余 eth
        bool isBuy;
        bool filled;
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
    function placeOrder(uint tokenAmount, uint ethAmount, bool isBuy) external {
        require(tokenAmount > 0 && ethAmount > 0, "Invalid amount");

        orders.push(
            Order({
                trader: msg.sender,
                remainingToken: tokenAmount,
                remainingEth: ethAmount,
                isBuy: isBuy,
                filled: false
            })
        );

        emit OrderPlaced(
            orders.length - 1,
            msg.sender,
            isBuy,
            tokenAmount,
            ethAmount
        );
    }

    // ================= 部分成交 =================
    function fillOrder(uint orderId, uint tokenAmount) external {
        require(orderId < orders.length, "Invalid order");

        Order storage order = orders[orderId];
        require(!order.filled, "Order finished");
        require(order.trader != msg.sender, "Self trade");
        require(tokenAmount > 0, "Zero fill");

        // 不能吃超过剩余量
        if (tokenAmount > order.remainingToken) {
            tokenAmount = order.remainingToken;
        }

        // 按比例算 ETH
        uint ethAmount = (order.remainingEth * tokenAmount) /
            order.remainingToken;

        if (order.isBuy) {
            // maker 用 ETH 买 token
            require(ethBalance[order.trader] >= ethAmount, "Maker no ETH");
            require(tokenBalance[msg.sender] >= tokenAmount, "Taker no token");

            tokenBalance[msg.sender] -= tokenAmount;
            tokenBalance[order.trader] += tokenAmount;

            ethBalance[order.trader] -= ethAmount;
            ethBalance[msg.sender] += ethAmount;
        } else {
            // maker 用 token 卖 ETH
            require(
                tokenBalance[order.trader] >= tokenAmount,
                "Maker no token"
            );
            require(ethBalance[msg.sender] >= ethAmount, "Taker no ETH");

            ethBalance[msg.sender] -= ethAmount;
            ethBalance[order.trader] += ethAmount;

            tokenBalance[order.trader] -= tokenAmount;
            tokenBalance[msg.sender] += tokenAmount;
        }

        // 更新剩余
        order.remainingToken -= tokenAmount;
        order.remainingEth -= ethAmount;

        emit OrderPartiallyFilled(
            orderId,
            order.trader,
            msg.sender,
            tokenAmount,
            ethAmount
        );

        // 是否完全成交
        if (order.remainingToken == 0) {
            order.filled = true;
            emit OrderFilled(orderId, order.trader);
        }
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
