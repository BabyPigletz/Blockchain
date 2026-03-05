
const { ethers } = require("hardhat");
const fs = require("fs");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("=========================================");
  console.log("  FinFlow Payments — Deployment Script  ");
  console.log("=========================================");
  console.log("Deployer address :", deployer.address);

  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("Deployer balance :", ethers.formatEther(balance), "HELA");
  console.log("");

  if (balance === 0n) {
    throw new Error("Deployer has no HELA. Get testnet tokens first!");
  }

  // A fresh random wallet is created as the AI oracle.
  // Its ADDRESS is stored in the contract (trusted signer).
  // Its PRIVATE KEY is used off-chain in the frontend to sign risk scores.
  const oracleWallet = ethers.Wallet.createRandom();
  console.log("Oracle address   :", oracleWallet.address);
  console.log("Oracle key       :", oracleWallet.privateKey);
  console.log("");

  console.log("Deploying FinFlowPayments...");
  const FinFlow = await ethers.getContractFactory("FinFlowPayments");
  const finflow = await FinFlow.deploy(oracleWallet.address);
  await finflow.waitForDeployment();

  const address = await finflow.getAddress();
  console.log("✅ FinFlowPayments deployed to:", address);

  const storedOracle = await finflow.trustedOracle();
  console.log("✅ Trusted oracle stored     :", storedOracle);

  const deployedData = {
    finflow: {
      address,
      name: "FinFlowPayments",
      deployer: deployer.address,
      network: "hela",
      chainId: 666888,
      deployedAt: new Date().toISOString(),
    },
    oracle: {
      address: oracleWallet.address,
      privateKey: oracleWallet.privateKey,
    },
  };

  fs.writeFileSync("deployedData.json", JSON.stringify(deployedData, null, 2));
  console.log("✅ deployedData.json saved!");

  console.log("");
  console.log("=========================================");
  console.log("  NEXT STEPS — update ui/config.js");
  console.log("=========================================");
  console.log("  CONTRACT_ADDRESS  :", address);
  console.log("  ORACLE_PRIVATE_KEY:", oracleWallet.privateKey);
  console.log("");
  console.log("  npx hardhat verify --network hela", address, oracleWallet.address);
  console.log("  https://testnet.helascan.io/address/" + address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});