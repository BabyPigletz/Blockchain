require("dotenv").config();
const express = require("express");
const cors    = require("cors");
const ethers  = require("ethers");

const app  = express();
const PORT = process.env.PORT || 3001;

app.use(cors());
app.use(express.json());

// Load oracle wallet from .env 
if (!process.env.ORACLE_PRIVATE_KEY) {
  console.error("ERROR: ORACLE_PRIVATE_KEY not set in .env");
  process.exit(1);
}
const oracleWallet = new ethers.Wallet(process.env.ORACLE_PRIVATE_KEY);
console.log("Oracle wallet loaded:", oracleWallet.address);

// AI Risk Scoring Logic simulated using rule based scoring

function inferCategory(memo) {
  const m = (memo || "").toLowerCase();
  if (m.match(/coffee|food|eat|lunch|dinner|pizza/)) return "Food & Beverage";
  if (m.match(/rent|house|apartment|lease/))          return "Housing";
  if (m.match(/invoice|service|work|contract|freelance/)) return "Business";
  if (m.match(/gift|birthday|thanks/))                return "Gift";
  return "Other";
}

function computeRiskScore(sender, recipient, amount, memo) {
  let score = 8;

  // Amount-based risk
  const amt = parseFloat(amount) || 0;
  if (amt > 1)  score += 20;
  if (amt > 5)  score += 30;
  if (amt > 20) score += 15; // extra risk for very large transfers

  // Memo-based risk
  if (!memo || memo.trim().length < 3) score += 20;

  // Sender/recipient relationship (same address = suspicious)
  if (sender && recipient && sender.toLowerCase() === recipient.toLowerCase()) {
    score += 30;
  }

  // Small random variance to simulate real model uncertainty
  score += Math.floor(Math.random() * 10);

  return Math.min(100, score);
}

// POST 
// Browser sends: { sender, recipient, amount, memo }
// Server returns: { riskScore, category, confidence, flags, recommendation, aiMetaHash, aiSignature }

app.post("/assess", async (req, res) => {
  try {
    const { sender, recipient, amount, memo } = req.body;

    // Validate inputs
    if (!sender || !recipient || !amount) {
      return res.status(400).json({ error: "Missing required fields: sender, recipient, amount" });
    }
    if (!ethers.isAddress(sender) || !ethers.isAddress(recipient)) {
      return res.status(400).json({ error: "Invalid sender or recipient address" });
    }

    // Compute risk score server-side
    const riskScore  = computeRiskScore(sender, recipient, amount, memo);
    const category   = inferCategory(memo);
    const confidence = 0.87 + Math.random() * 0.1;
    const flags      = [];
    if (parseFloat(amount) > 5)          flags.push("high_value");
    if (!memo || memo.trim().length < 3) flags.push("vague_memo");
    if (riskScore >= 75)                 flags.push("escrow_required");

    const recommendation = riskScore >= 75 ? "escrow"
                         : riskScore >= 40 ? "review"
                         : "approve";

    // Hash the AI metadata
    const metaJson   = JSON.stringify({ riskScore, category, confidence, flags, ts: Date.now() });
    const aiMetaHash = ethers.keccak256(ethers.toUtf8Bytes(metaJson));

    // Oracle signs keccak256(sender, recipient, riskScore, aiMetaHash)
    // This is the same hash the smart contract will reconstruct and verify
    const msgHash = ethers.keccak256(
      ethers.solidityPacked(
        ["address", "address", "uint8", "bytes32"],
        [sender, recipient, riskScore, aiMetaHash]
      )
    );
    const aiSignature = await oracleWallet.signMessage(ethers.getBytes(msgHash));

    console.log(`[ASSESS] sender=${sender.slice(0,8)}... amount=${amount} score=${riskScore} rec=${recommendation}`);

    // Return signed result to browser
    res.json({
      riskScore,
      category,
      confidence: parseFloat(confidence.toFixed(4)),
      flags,
      recommendation,
      aiMetaHash,
      aiSignature,
      oracleAddress: oracleWallet.address,
    });

  } catch (err) {
    console.error("Error in /assess:", err.message);
    res.status(500).json({ error: "Oracle assessment failed: " + err.message });
  }
});

// ── GET
// Simple health check 

app.get("/health", (req, res) => {
  res.json({
    status: "ok",
    oracle: oracleWallet.address,
    timestamp: new Date().toISOString(),
  });
});

// Start server 
app.listen(PORT, () => {
  console.log("");
  console.log("=========================================");
  console.log("  FinFlow Oracle Server running");
  console.log("=========================================");
  console.log(`  Port    : ${PORT}`);
  console.log(`  Oracle  : ${oracleWallet.address}`);
  console.log(`  Health  : http://localhost:${PORT}/health`);
  console.log(`  Assess  : POST http://localhost:${PORT}/assess`);
  console.log("=========================================");
  console.log("");
});