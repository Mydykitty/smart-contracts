import { ethers } from "ethers";
import fs from "fs";

const RPC_URL = "http://127.0.0.1:8545";

const MINIDEX = "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512";
const TOKEN = "0x5FbDB2315678afecb367f032d93F642f64180aa3";

async function main() {
  const provider = new ethers.JsonRpcProvider(RPC_URL);

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

  const dex = new ethers.Contract(MINIDEX, dexAbi, alice);
  const token = new ethers.Contract(TOKEN, tokenAbi, alice);

  // ===== 1. Alice 存 ETH =====
  // await dex.depositETH({ value: ethers.parseEther("10") });
  // console.log("Alice deposited 10 ETH");

  // ===== 2. Alice 存 Token =====
  await token.approve(MINIDEX, ethers.parseEther("100"));
  await dex.depositToken(ethers.parseEther("100"));
  console.log("Alice deposited 100 TKN");

  // ===== 3. Alice 挂卖单 =====
  await dex.placeOrder(
    ethers.parseEther("100"), // tokenAmount
    ethers.parseEther("5"), // ethAmount
    false, // isBuy = false (卖单)
  );
  console.log("Alice placed sell order");

  // ===== 4. Bob 吃单（只成交未成交订单） =====
  const dexAsBob = dex.connect(bob);

  const ordersCount = Number(await dex.getOrdersCount());
  console.log("Total orders:", ordersCount);

  for (let i = 0; i < ordersCount; i++) {
    const order = await dex.orders(i);
    if (!order.filled) {
      // 确保 Bob 余额够支付
      if (order.isBuy) {
        // 买单：Bob 卖 Token
        const bobTokenBal = await dex.tokenBalance(await bob.getAddress());
        if (bobTokenBal < order.tokenAmount) {
          console.log(`Bob has insufficient token for order #${i}`);
          continue;
        }
      } else {
        // 卖单：Bob 买 Token，用 ETH
        const bobEthBal = await dex.ethBalance(await bob.getAddress());
        if (bobEthBal < order.ethAmount) {
          // 如果 ETH 不够，先充值
          await dexAsBob.depositETH({ value: order.ethAmount });
          console.log(
            `Bob deposited ${ethers.formatEther(order.ethAmount)} ETH for order #${i}`,
          );
        }
      }

      // 尝试填单
      try {
        await dexAsBob.fillOrder(i);
        console.log(`Bob filled order #${i}`);
      } catch (err) {
        console.log(`Failed to fill order #${i}:`, err.message);
      }
    } else {
      console.log(`Order #${i} already filled`);
    }
  }

  // ===== 5. 查询余额 =====
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
