# Blockchain Assignment -FinFlow

FinFlow is a decentralized payment DApp with AI-powered risk scoring and escrow protection. Every payment is settled on-chain on HeLa Testnet. High-risk payments (score ≥ 75) are automatically escrowed. The AI oracle sign its risk assessment off-chain; the smart contract verifies the signature on-chain using Elliptic Curve Digital Signature Algorithm (ECDSA).

## Project Structure

```
Blockchain/
├── contracts/
│   └── FinFlowPayments.sol     Smart contract (Solidity 0.8.33)
├── scripts/
│   └── deploy.js               Deployment script → generates deployedData.json
├── oracle-server/
│   ├── server.js               Oracle Server (Node.js)
│   ├── package.js
│   └── .env.example            Oracle Orivate Key Template 
├── ui/
│   ├── index.html              Frontend (open with Live Server)
│   └── config.js               Contract address + ABI + oracle key
├── hardhat.config.js           Hardhat config with HeLa Testnet network
├── package.json
├── .env.example                Private key template
└── .gitignore
```
---

## Prerequisites
| Tool | Version | Download |
|---|---|---|
| Node.js | ≥ 18.x (LTS) | https://nodejs.org |
| npm | ≥ 9.x (bundled with Node) | — |
| MetaMask | Latest | https://metamask.io |
| VS Code + Live Server extension | Latest | https://code.visualstudio.com |

Verify Node is installed:
```bash
node --version
npm --version
```

--- 

## Step 1 - Clone the Project

Clone the project to your machine using:
```bash
git clone https://github.com/BabyPigletz/Blockchain.git
cd Blockchain
```

---

## Step 2 - Install Dependencies
```bash
npm install
```

Expected output:
```
added 291 packages in 30s
```

---

## Step 3 - Configure Environment

Create and open `.env` and paste your MetaMask deployer private key:
```
HELA_PRIVATE_KEY_DEPLOY_ACCOUNT=0xYOUR_PRIVATE_KEY_HERE
```

**How to get your private key from MetaMask:**
1. Open MetaMask → three dots next to your account name
2. Account Details → Show private key
3. Enter your MetaMask password → copy the key

> Never commit `.env` to Git. It is already in `.gitignore`.

---

## Step 4 - Add HeLa Testnet to Metamask

MetaMask → Settings → Networks → Add Network → Add manually:

| Field | Value |
|---|---|
| Network Name | HeLa Testnet |
| RPC URL | https://testnet-rpc.helachain.com |
| Chain ID | 666888 |
| Currency Symbol | HELA |
| Block Explorer | https://testnet.helascan.io |

---

## Step 5 - Get Testnet HELA Tokens

Visit https://testnet-faucet.helachain.com/ to get HELA. Confirm your MetaMask balance shows > 0 HELA before continuing

-- 

## Step 6 - Compile the Contract

```bash
npx hardhat compile
```

Expected output:
```
Compiled 1 Solidity file successfully (evm target: paris).
```

---

## Step 7 — Deploy to HeLa Testnet

```bash
npx hardhat run scripts/deploy.js --network hela
```

Expected output:
```
=========================================
  FinFlow Payments — Deployment Script
=========================================
Deployer address : 0xYourAddress...
Deployer balance : 1.5 HELA

Oracle address   : 0xOracleAddress...
Oracle key       : 0xOraclePrivateKey...

Deploying FinFlowPayments...
✅ FinFlowPayments deployed to: 0xContractAddress...
✅ Trusted oracle stored      : 0xOracleAddress...
✅ deployedData.json saved!

=========================================
  NEXT STEPS — update ui/config.js
=========================================
  CONTRACT_ADDRESS  : 0xContractAddress...
  ORACLE_PRIVATE_KEY: 0xOraclePrivateKey...
```

---

## Step 8 - Update ui/config.js

Open `ui/config.js` and replace the two placeholder values with the output from Step 7:

```javascript
CONTRACT_ADDRESS: "0xYourDeployedContractAddress",
ORACLE_URL: "http://localhost:3001",
```

Open `artifacts/build-info` and locate the json file found in the folder. It should look something similar to this `aae84e45c8be91829d2541bf321b77c3.json`. Right click to Format Document or use `Shift+ALT+F`. Locate the following:

```javascript
"input": {.....}, 
```
You might have to hover over the row number and collapse to find the end of the input code. Only copy the brackets content including the brackets:
```javascript
{}
```
Create a json file called `input.json` and paste the content inside. We will be using it later.

---

## Step 9 - Configure and Start Oracle Server

The oracle server is a separate Node.js process that computes AI risk scores and signs them server-side. The private key  never reaches the browser.

Navigate to the oracle-server folder:
```bash
cd oracle-server
```

Install dependencies if needed

```bash
npm install
```

Create the .env file
```bash
copy .env.example .env
```

Open .env and paste the oracle private key from `deployedData.json`:
```javascript
ORACLE_PRIVATE_KEY=0xYourOraclePrivateKey
PORT=3001
```

Start the Oracle Server:
```bash
npm start
```

Expected Output:
```
=========================================
  FinFlow Oracle Server running
=========================================
  Port    : 3001
  Oracle  : 0xYourOracleAddress...
  Health  : http://localhost:3001/health
=========================================
```

Verify that the oracle is running by visiting:
`http://localhost:3001/health`

You should see: `{ "status": "ok", "oracle": "0x..." }`
Keep this terminal open. The oracle server must be running before you open the frontend!

---

## Step 10 - Verify on HeLa Scan
Visit https://testnet.helascan.io — search your contract → Contract tab → Verify and Publish → Compiler `v0.8.33`, License MIT, paste `input.json`.

---

## Step 11 — Run the Frontend
```
Before opening the frontend, ensure:
- Oracle server is running on port 3001 (Step 9)
- MetaMask is installed and connected to HeLa Testnet
```
1. Open `ui/index.html` in VS Code
2. Right-click → **Open with Live Server**
3. Browser opens at `http://127.0.0.1:5500/ui/`

---

## Step 12 — Test the Full Flow

**Normal payment (low risk):**
- Amount: `0.5`, Memo: `lunch` → AI score < 75 → direct transfer

**Trigger auto-escrow (high risk):**
- Amount: `10`, Memo: `a` → AI score ≥ 75 → funds locked in contract

**Release or refund escrow:**
- Escrow tab → enter Payment ID → Release to Recipient or Refund to Sender

**Lookup any payment:**
- Escrow tab → Lookup Payment → enter Payment ID → Fetch from Chain

---

## Troubleshooting

| Error | Fix |
|---|---|
| `npm is not recognized` | Install Node.js from nodejs.org, reopen terminal |
| `Cannot find module` | Run `npm install` first |
| `Deployer has no HELA` | Get testnet tokens before deploying |
| `incorrect number of arguments to constructor` | Run `npx hardhat clean` then recompile |
| `Update CONTRACT_ADDRESS` | Paste deployed address from Step 7 into config.js |
| `Set ORACLE_PRIVATE_KEY` | Paste oracle key from Step 7 into config.js |
| `Not enough HELA tokens` | Top up wallet with testnet HELA |
| `Transaction cancelled` | Clicked Reject in MetaMask — try again |
| `Oracle server not reachable` | Run `cd oracle-server && npm start` in a separate terminal |
| `Oracle server error` | Check ORACLE_PRIVATE_KEY is set correctly in oracle-server/.env |
| `Port 3001 already in use` | Change PORT in oracle-server/.env and update ORACLE_URL in config.js to match |
