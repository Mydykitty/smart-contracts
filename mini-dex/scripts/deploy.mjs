import hre from "hardhat";
import { ethers } from "ethers";
import fs from "fs";

async function main() {
    // Ethers 直连 JSON-RPC
  const provider = new ethers.JsonRpcProvider("http://127.0.0.1:8545");
  const signer = await provider.getSigner(0);

  console.log("Deploying with:", await signer.getAddress());

  // ===== 读取 TestToken artifact =====
  const testTokenArtifact = JSON.parse(
    fs.readFileSync(
      "./artifacts/contracts/TestToken.sol/TestToken.json",
      "utf8"
    )
  );

  const TestTokenFactory = new ethers.ContractFactory(
    testTokenArtifact.abi,
    testTokenArtifact.bytecode,
    signer
  );

  const token = await TestTokenFactory.deploy();
  await token.waitForDeployment();
   const tokenAddress = await token.getAddress();

  console.log("TestToken deployed at:", tokenAddress);

  // ===== 读取 MiniDex artifact =====
  const miniDexArtifact = JSON.parse(
    fs.readFileSync(
      "./artifacts/contracts/MiniDex.sol/MiniDex.json",
      "utf8"
    )
  );

  const MiniDexFactory = new ethers.ContractFactory(
    miniDexArtifact.abi,
    miniDexArtifact.bytecode,
    signer
  );

  const dex = await MiniDexFactory.deploy(tokenAddress);
  await dex.waitForDeployment();

  console.log("MiniDex deployed at:", await dex.getAddress());
}

main().catch(console.error);
