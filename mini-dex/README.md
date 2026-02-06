# Sample Hardhat 3 Beta Project (minimal)

This project has a minimal setup of Hardhat 3 Beta, without any plugins.

## What's included?

The project includes native support for TypeScript, Hardhat scripts, tasks, and support for Solidity compilation and tests.

rm -rf node_modules package-lock.json

npm install --save-dev hardhat@3.1.7 --legacy-peer-deps
npm install ethers --legacy-peer-deps

terminal1
npx hardhat node

terminal2
npx hardhat run scripts/deploy.mjs --network localhost
npx hardhat run scripts/play.mjs --network localhost

1. 安装 Prettier 和 Solidity 插件

2. npm install --save-dev prettier prettier-plugin-solidity --legacy-peer-deps

3. open user setting.json

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

4. Shift + Option + F（Mac）来手动格式化当前文件
