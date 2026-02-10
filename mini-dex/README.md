# MiniDex v5（Hardhat 3 Beta 示例项目）

这是一个最小化 Hardhat 3 Beta 项目，实现了一个 **DEX 原型**，包含：

- ERC20 代币支持
- 内部 `available / locked` 余额模型
- 部分成交（Partial Fill）
- Maker / Taker 手续费

项目适合 **学习、测试和实验**交易所订单簿逻辑。

---

## ⚡ 功能特性

### 1. ERC20 代币支持
- TestToken 是标准 ERC20（部署时可 mint）。
- 支持存入和提取 ERC20 代币。

### 2. 内部余额模型
- `available` / `locked` 模型防止超额使用资产。
- ETH 和代币余额分开：
    - `available`：可提取或用于新订单
    - `locked`：已挂单冻结的资产

### 3. 订单簿
- 支持挂买单 / 卖单。
- 支持 **部分成交**：订单可多次被吃，直到完全成交。
- 支持撤单，释放冻结资产。

### 4. 手续费系统
- Maker / Taker 手续费模式。
- 每次成交扣除手续费，发送到 `feeReceiver`。
- 手续费使用 basis points（bps）计算，保证精度。

### 5. 事件通知
- `OrderPlaced`、`OrderPartiallyFilled`、`OrderFilled`、`OrderCancelled`
- `FeeCollected` 用于监控手续费

---

## ⚙️ 环境搭建

### 1. 安装依赖

```bash
rm -rf node_modules package-lock.json
npm install --save-dev hardhat@3.1.7 --legacy-peer-deps
npm install ethers --legacy-peer-deps
```

### 2. 启动本地节点 (terminal1)
```bash
npx hardhat node
```

### 3. 部署合约 (terminal2)
```bash
npx hardhat run scripts/deploy.mjs --network localhost
```
部署后请更新 scripts/playCancel.mjs 中的合约地址。

### 4. 运行交互脚本
```bash
npx hardhat run scripts/playCancel.mjs --network localhost
```

## 🛠️ 推荐 VSCode 配置

### 1. Prettier + Solidity 自动格式化

```bash
npm install --save-dev prettier prettier-plugin-solidity --legacy-peer-deps
```
settings.json
```bash
"editor.formatOnSave": true,
"[solidity]": {
"editor.formatOnSave": true
},
"[javascript]": {
"editor.formatOnSave": true,
"editor.defaultFormatter": "esbenp.prettier-vscode"
},
"[javascriptreact]": {
"editor.formatOnSave": true
},
"[typescript]": {
"editor.formatOnSave": true
},
"[typescriptreact]": {
"editor.formatOnSave": true
},
"[json]": {
"editor.formatOnSave": true
}
```
Shift + Option + F（Mac）来手动格式化当前文件
## ✅ 注意事项
本项目仅用于 实验和学习，不适合生产环境。

重点学习 订单簿逻辑、available/locked、部分成交和手续费机制。

安全性（如前置攻击、重入攻击、Gas 优化）尚未全面考虑。

后续可拓展：

增加更完善的 测试套件（Foundry / Hardhat）

支持 动态手续费调整

支持 市价单 / 批量成交

集成简单 前端展示订单簿
