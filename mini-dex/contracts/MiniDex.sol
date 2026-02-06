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

    // 用户在交易所里的余额
    mapping(address => uint) public ethBalance;
    mapping(address => uint) public tokenBalance;

    struct Order {
        address trader;
        uint tokenAmount;
        uint ethAmount;
        bool isBuy; // true = 买单, false = 卖单
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
        if (isBuy) {
            require(ethBalance[msg.sender] >= ethAmount, "Not enough ETH");
            ethBalance[msg.sender] -= ethAmount; // 🔒 锁 ETH
        } else {
            require(
                tokenBalance[msg.sender] >= tokenAmount,
                "Not enough Token"
            );
            tokenBalance[msg.sender] -= tokenAmount; // 🔒 锁 Token
        }

        orders.push(Order(msg.sender, tokenAmount, ethAmount, isBuy, false));
    }

    // ================= 撮合成交 =================

    function fillOrder(uint orderId) external {
        require(orderId < orders.length, "Invalid order");

        Order storage order = orders[orderId];
        require(!order.filled, "Already filled");
        require(order.trader != msg.sender, "Self trade");

        if (order.isBuy) {
            // 买单：买家用 ETH 买 token（ETH 已锁）
            require(tokenBalance[msg.sender] >= order.tokenAmount, "No token");

            tokenBalance[msg.sender] -= order.tokenAmount;
            tokenBalance[order.trader] += order.tokenAmount;

            ethBalance[msg.sender] += order.ethAmount;
        } else {
            // 卖单：卖家用 token 卖 ETH（token 已锁）
            require(ethBalance[msg.sender] >= order.ethAmount, "No ETH");

            ethBalance[msg.sender] -= order.ethAmount;
            ethBalance[order.trader] += order.ethAmount;

            tokenBalance[msg.sender] += order.tokenAmount;
        }

        order.filled = true;
    }

    // ================= 查询 =================

    function getOrdersCount() external view returns (uint) {
        return orders.length;
    }

    // ================= 撤单 =================
    function cancelOrder(uint orderId) external {
        require(orderId < orders.length, "Invalid order");

        Order storage order = orders[orderId];
        require(order.trader == msg.sender, "Not your order");
        require(!order.filled, "Order already filled");

        // 标记为已成交（防止重复操作）
        order.filled = true;

        // 返还锁定资产
        if (order.isBuy) {
            // 买单：返还锁定的 ETH
            ethBalance[msg.sender] += order.ethAmount;
        } else {
            // 卖单：返还锁定的 Token
            tokenBalance[msg.sender] += order.tokenAmount;
        }
    }
}
