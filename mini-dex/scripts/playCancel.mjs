import { ethers } from "ethers";
import fs from "fs";

const RPC_URL = "http://127.0.0.1:8545";

// 替换为你本地部署的合约地址

const MINIDEX = "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512";
const TOKEN = "0x5FbDB2315678afecb367f032d93F642f64180aa3";

async function main() {
  const provider = new ethers.JsonRpcProvider(RPC_URL);

  // Alice 和 Bob
  const alice = await provider.getSigner(0);
  const bob = await provider.getSigner(1);

  console.log("Alice:", await alice.getAddress());
  console.log("Bob  :", await bob.getAddress());

  // ===== 读取 ABI =====
  const dexAbi = JSON.parse(
    fs.readFileSync("./artifacts/contracts/MiniDex.sol/MiniDex.json", "utf8"),
  ).abi;

  const tokenAbi = JSON.parse(
    fs.readFileSync(
      "./artifacts/contracts/TestToken.sol/TestToken.json",
      "utf8",
    ),
  ).abi;

  // ===== 创建合约实例 =====
  const dex = new ethers.Contract(MINIDEX, dexAbi, alice);
  const token = new ethers.Contract(TOKEN, tokenAbi, alice);

  // ===== 1. Alice 存 ETH 和 Token =====
  await dex.depositETH({ value: ethers.parseEther("10") });
  console.log("Alice deposited 10 ETH");

  await token.approve(MINIDEX, ethers.parseEther("200"));
  await dex.depositToken(ethers.parseEther("200"));
  console.log("Alice deposited 200 TKN");

  // ===== 2. Alice 挂两个卖单 =====
  await dex.placeOrder(
    ethers.parseEther("100"), // tokenAmount
    ethers.parseEther("5"), // ethAmount
    false, // isBuy = false
  );
  console.log("Alice placed sell order #0");

  await dex.placeOrder(
    ethers.parseEther("50"), // tokenAmount
    ethers.parseEther("2"), // ethAmount
    false,
  );
  console.log("Alice placed sell order #1");

  // ===== 3. Bob 吃第一个卖单 =====
  const dexAsBob = dex.connect(bob);

  const ordersCount = Number(await dex.getOrdersCount());
  console.log("Total orders:", ordersCount);

  for (let i = 0; i < ordersCount; i++) {
    const order = await dex.orders(i);
    if (!order.filled) {
      // 卖单：Bob 用 ETH 买 Token
      const bobEthBal = await dex.ethBalance(await bob.getAddress());
      if (bobEthBal < order.ethAmount) {
        await dexAsBob.depositETH({ value: order.ethAmount });
        console.log(
          `Bob deposited ${ethers.formatEther(order.ethAmount)} ETH for order #${i}`,
        );
      }

      await dexAsBob.fillOrder(i);
      console.log(`Bob filled order #${i}`);
      // 只吃第一个挂单
      break;
    }
  }

  // ===== 4. Alice 撤第二个未成交卖单 =====
  for (let i = 0; i < ordersCount; i++) {
    const order = await dex.orders(i);
    if (
      !order.filled &&
      order.trader.toLowerCase() === (await alice.getAddress()).toLowerCase()
    ) {
      await dex.cancelOrder(i);
      console.log(`Alice canceled order #${i}`);
    }
  }

  // ===== 5. 查询最终余额 =====
  const aliceEth = await dex.ethBalance(await alice.getAddress());
  const aliceToken = await dex.tokenBalance(await alice.getAddress());
  const bobEth = await dex.ethBalance(await bob.getAddress());
  const bobToken = await dex.tokenBalance(await bob.getAddress());

  console.log("\n=== Final DEX Balances ===");
  console.log("Alice ETH  :", ethers.formatEther(aliceEth));
  console.log("Alice TKN  :", ethers.formatEther(aliceToken));
  console.log("Bob   ETH  :", ethers.formatEther(bobEth));
  console.log("Bob   TKN  :", ethers.formatEther(bobToken));
}

main().catch(console.error);
