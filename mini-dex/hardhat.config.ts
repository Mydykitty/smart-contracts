import { defineConfig } from "hardhat/config";

export default defineConfig({
  solidity: "0.8.20",
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545",
    },
  },
});
