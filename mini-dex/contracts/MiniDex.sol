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

    // ================= 余额模型 =================
    mapping(address => uint) public availableEth;
    mapping(address => uint) public lockedEth;

    mapping(address => uint) public availableToken;
    mapping(address => uint) public lockedToken;

    // ================= Events =================
    event DepositETH(address indexed user, uint amount);
    event DepositToken(address indexed user, uint amount);
    event WithdrawETH(address indexed user, uint amount);
    event WithdrawToken(address indexed user, uint amount);

    event OrderPlaced(uint indexed orderId, address indexed trader, bool isBuy);
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
        address trader;          // maker
        uint remainingToken;
        uint remainingEth;
        bool isBuy;
        bool finished;
    }

    Order[] public orders;

    // ================= 充值 =================
    function depositETH() external payable {
        availableEth[msg.sender] += msg.value;
        emit DepositETH(msg.sender, msg.value);
    }

    receive() external payable {
        availableEth[msg.sender] += msg.value;
        emit DepositETH(msg.sender, msg.value);
    }

    function depositToken(uint amount) external {
        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        availableToken[msg.sender] += amount;
        emit DepositToken(msg.sender, amount);
    }

    // ================= 提现 =================
    function withdrawETH(uint amount) external {
        require(availableEth[msg.sender] >= amount, "Not enough ETH");
        availableEth[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
        emit WithdrawETH(msg.sender, amount);
    }

    function withdrawToken(uint amount) external {
        require(availableToken[msg.sender] >= amount, "Not enough token");
        availableToken[msg.sender] -= amount;
        require(token.transfer(msg.sender, amount), "Transfer failed");
        emit WithdrawToken(msg.sender, amount);
    }

    // ================= 挂单（锁仓） =================
    function placeOrder(
        uint tokenAmount,
        uint ethAmount,
        bool isBuy
    ) external {
        require(tokenAmount > 0 && ethAmount > 0, "Invalid amount");

        if (isBuy) {
            // 买单：锁 ETH
            require(availableEth[msg.sender] >= ethAmount, "No ETH");
            availableEth[msg.sender] -= ethAmount;
            lockedEth[msg.sender] += ethAmount;
        } else {
            // 卖单：锁 Token
            require(availableToken[msg.sender] >= tokenAmount, "No token");
            availableToken[msg.sender] -= tokenAmount;
            lockedToken[msg.sender] += tokenAmount;
        }

        orders.push(
            Order({
                trader: msg.sender,
                remainingToken: tokenAmount,
                remainingEth: ethAmount,
                isBuy: isBuy,
                finished: false
            })
        );

        emit OrderPlaced(orders.length - 1, msg.sender, isBuy);
    }

    // ================= 部分成交 =================
    function fillOrder(uint orderId, uint tokenAmount) external {
        require(orderId < orders.length, "Invalid order");

        Order storage order = orders[orderId];
        require(!order.finished, "Order finished");
        require(order.trader != msg.sender, "Self trade");
        require(tokenAmount > 0, "Zero fill");

        if (tokenAmount > order.remainingToken) {
            tokenAmount = order.remainingToken;
        }

        uint ethAmount;
        if (tokenAmount == order.remainingToken) {
            ethAmount = order.remainingEth; // 吃掉 dust
        } else {
            ethAmount =
                (order.remainingEth * tokenAmount) / order.remainingToken;
        }

        if (order.isBuy) {
            // maker 锁 ETH，taker 出 Token
            require(availableToken[msg.sender] >= tokenAmount, "Taker no token");

            availableToken[msg.sender] -= tokenAmount;
            availableToken[order.trader] += tokenAmount;

            lockedEth[order.trader] -= ethAmount;
            availableEth[msg.sender] += ethAmount;
        } else {
            // maker 锁 Token，taker 出 ETH
            require(availableEth[msg.sender] >= ethAmount, "Taker no ETH");

            availableEth[msg.sender] -= ethAmount;
            availableEth[order.trader] += ethAmount;

            lockedToken[order.trader] -= tokenAmount;
            availableToken[msg.sender] += tokenAmount;
        }

        order.remainingToken -= tokenAmount;
        order.remainingEth -= ethAmount;

        emit OrderPartiallyFilled(
            orderId,
            order.trader,
            msg.sender,
            tokenAmount,
            ethAmount
        );

        if (order.remainingToken == 0) {
            order.finished = true;

            // 解锁剩余（理论上应为 0，但写出来更安全）
            if (order.isBuy && order.remainingEth > 0) {
                lockedEth[order.trader] -= order.remainingEth;
                availableEth[order.trader] += order.remainingEth;
            }
            if (!order.isBuy && order.remainingToken > 0) {
                lockedToken[order.trader] -= order.remainingToken;
                availableToken[order.trader] += order.remainingToken;
            }

            emit OrderFilled(orderId, order.trader);
        }
    }

    // ================= 撤单 =================
    function cancelOrder(uint orderId) external {
        require(orderId < orders.length, "Invalid order");

        Order storage order = orders[orderId];
        require(order.trader == msg.sender, "Not your order");
        require(!order.finished, "Already finished");

        order.finished = true;

        // 解锁剩余资产
        if (order.isBuy) {
            lockedEth[msg.sender] -= order.remainingEth;
            availableEth[msg.sender] += order.remainingEth;
        } else {
            lockedToken[msg.sender] -= order.remainingToken;
            availableToken[msg.sender] += order.remainingToken;
        }

        emit OrderCancelled(orderId, msg.sender);
    }

    // ================= 查询 =================
    function getOrdersCount() external view returns (uint) {
        return orders.length;
    }
}
