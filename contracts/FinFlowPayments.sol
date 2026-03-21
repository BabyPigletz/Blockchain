// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

contract FinFlowPayments {

    // ── State ─────────────────────────────────────────────────────────────────

    address public owner;
    address public pauser;
    address public trustedOracle;  
    bool    public paused;

    uint256 public constant MAX_FEE_BPS = 300;  // 3% hard cap
    uint256 public protocolFeeBps = 50;          // 0.5% default
    uint256 public accumulatedFees;
    uint256 private _txCounter;

    enum PaymentStatus { Pending, Completed, Escrowed, Released, Refunded }

    struct Payment {
        uint256       id;
        address       sender;
        address       recipient;
        uint256       amount;
        uint256       fee;
        uint256       netAmount;
        uint256       timestamp;
        string        memo;
        bytes32       aiMetadataHash;
        uint8         riskScore;
        PaymentStatus status;
    }

    mapping(uint256 => Payment)   public payments;
    mapping(address => uint256[]) private _sentPayments;
    mapping(address => uint256[]) private _receivedPayments;
    mapping(uint256 => uint256)   public escrowBalance;

    event PaymentSent(
        uint256 indexed id,
        address indexed sender,
        address indexed recipient,
        uint256 amount,
        uint256 netAmount,
        string  memo,
        uint8   riskScore
    );
    event PaymentEscrowed(uint256 indexed id, address indexed sender, address indexed recipient, uint256 amount);
    event EscrowReleased(uint256 indexed id, address indexed releasedBy);
    event EscrowRefunded(uint256 indexed id, address indexed refundedBy);
    event FeeUpdated(uint256 oldFeeBps, uint256 newFeeBps);
    event FeesWithdrawn(address indexed to, uint256 amount);
    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event OracleUpdated(address indexed oldOracle, address indexed newOracle);

    modifier onlyOwner() {
        require(msg.sender == owner, "FinFlow: not owner");
        _;
    }
    modifier onlyOwnerOrPauser() {
        require(msg.sender == owner || msg.sender == pauser, "FinFlow: unauthorized");
        _;
    }
    modifier whenNotPaused() {
        require(!paused, "FinFlow: paused");
        _;
    }
    modifier validAddress(address addr) {
        require(addr != address(0), "FinFlow: zero address");
        require(addr != address(this), "FinFlow: self send");
        _;
    }

    constructor(address _oracle) {
        require(_oracle != address(0), "FinFlow: zero oracle");
        owner         = msg.sender;
        pauser        = msg.sender;
        trustedOracle = _oracle;
    }

    function sendPayment(
        address recipient,
        string  calldata memo,
        bytes32 aiMetaHash,
        uint8   riskScore,
        bytes   calldata aiSignature
    )
        external
        payable
        whenNotPaused
        validAddress(recipient)
        returns (uint256 paymentId)
    {
        require(msg.value > 0,             "FinFlow: zero value");
        require(riskScore <= 100,          "FinFlow: invalid risk score");
        require(bytes(memo).length <= 256, "FinFlow: memo too long");

        // Verify the AI oracle signed this risk score — on-chain proof
        _verifyOracleSignature(msg.sender, recipient, riskScore, aiMetaHash, aiSignature);

        // High-risk → auto-escrow
        if (riskScore >= 75) {
            return _createEscrow(recipient, memo, aiMetaHash, riskScore);
        }

        return _recordPayment(recipient, memo, aiMetaHash, riskScore);
    }

    function sendToEscrow(
        address recipient,
        string  calldata memo,
        bytes32 aiMetaHash,
        uint8   riskScore,
        bytes   calldata aiSignature
    )
        external
        payable
        whenNotPaused
        validAddress(recipient)
        returns (uint256 paymentId)
    {
        require(msg.value > 0, "FinFlow: zero value");
        _verifyOracleSignature(msg.sender, recipient, riskScore, aiMetaHash, aiSignature);
        return _createEscrow(recipient, memo, aiMetaHash, riskScore);
    }

    function releaseEscrow(uint256 paymentId) external whenNotPaused {
        Payment storage p = payments[paymentId];
        require(p.status == PaymentStatus.Escrowed,            "FinFlow: not escrowed");
        require(msg.sender == p.sender || msg.sender == owner, "FinFlow: unauthorized");

        uint256 fee       = _calcFee(p.amount);
        uint256 netAmount = p.amount - fee;
        accumulatedFees  += fee;

        p.fee       = fee;
        p.netAmount = netAmount;
        p.status    = PaymentStatus.Released;
        escrowBalance[paymentId] = 0;

        (bool ok,) = p.recipient.call{value: netAmount}("");
        require(ok, "FinFlow: release failed");

        emit EscrowReleased(paymentId, msg.sender);
    }

    function refundEscrow(uint256 paymentId) external whenNotPaused {
        Payment storage p = payments[paymentId];
        require(p.status == PaymentStatus.Escrowed,            "FinFlow: not escrowed");
        require(msg.sender == p.sender || msg.sender == owner, "FinFlow: unauthorized");

        uint256 amount = p.amount;
        p.status = PaymentStatus.Refunded;
        escrowBalance[paymentId] = 0;

        (bool ok,) = p.sender.call{value: amount}("");
        require(ok, "FinFlow: refund failed");

        emit EscrowRefunded(paymentId, msg.sender);
    }

    function getPayment(uint256 paymentId) external view returns (Payment memory) {
        require(payments[paymentId].id != 0, "FinFlow: not found");
        return payments[paymentId];
    }

    function getSentPayments(address user) external view returns (uint256[] memory) {
        return _sentPayments[user];
    }

    function getReceivedPayments(address user) external view returns (uint256[] memory) {
        return _receivedPayments[user];
    }

    function totalPayments() external view returns (uint256) {
        return _txCounter;
    }

    function calcFee(uint256 amount) external view returns (uint256) {
        return _calcFee(amount);
    }

    function _calcFee(uint256 amount) internal view returns (uint256) {
        return (amount * protocolFeeBps) / 10_000;
    }

    function _verifyOracleSignature(
        address sender,
        address recipient,
        uint8   riskScore,
        bytes32 aiMetaHash,
        bytes   calldata aiSignature
    ) internal view {
        bytes32 msgHash = keccak256(
            abi.encodePacked(sender, recipient, riskScore, aiMetaHash)
        );
        bytes32 ethHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", msgHash)
        );
        address recovered = _recoverSigner(ethHash, aiSignature);
        require(recovered == trustedOracle, "FinFlow: invalid oracle signature");
    }

    function _recordPayment(
        address recipient,
        string  calldata memo,
        bytes32 aiMetaHash,
        uint8   riskScore
    ) internal returns (uint256 paymentId) {
        uint256 fee       = _calcFee(msg.value);
        uint256 netAmount = msg.value - fee;
        accumulatedFees  += fee;

        _txCounter++;
        paymentId = _txCounter;

        payments[paymentId] = Payment({
            id:             paymentId,
            sender:         msg.sender,
            recipient:      recipient,
            amount:         msg.value,
            fee:            fee,
            netAmount:      netAmount,
            timestamp:      block.timestamp,
            memo:           memo,
            aiMetadataHash: aiMetaHash,
            riskScore:      riskScore,
            status:         PaymentStatus.Completed
        });

        _sentPayments[msg.sender].push(paymentId);
        _receivedPayments[recipient].push(paymentId);

        (bool ok,) = recipient.call{value: netAmount}("");
        require(ok, "FinFlow: transfer failed");

        emit PaymentSent(paymentId, msg.sender, recipient, msg.value, netAmount, memo, riskScore);
    }

    function _recoverSigner(bytes32 ethSignedHash, bytes memory sig) internal pure returns (address) {
        require(sig.length == 65, "FinFlow: invalid signature length");
        bytes32 r;
        bytes32 s;
        uint8   v;
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
        if (v < 27) v += 27;
        require(v == 27 || v == 28, "FinFlow: invalid signature v");
        return ecrecover(ethSignedHash, v, r, s);
    }

    function _createEscrow(
        address recipient,
        string  calldata memo,
        bytes32 aiMetaHash,
        uint8   riskScore
    ) internal returns (uint256 paymentId) {
        _txCounter++;
        paymentId = _txCounter;

        payments[paymentId] = Payment({
            id:             paymentId,
            sender:         msg.sender,
            recipient:      recipient,
            amount:         msg.value,
            fee:            0,
            netAmount:      0,
            timestamp:      block.timestamp,
            memo:           memo,
            aiMetadataHash: aiMetaHash,
            riskScore:      riskScore,
            status:         PaymentStatus.Escrowed
        });

        escrowBalance[paymentId] = msg.value;
        _sentPayments[msg.sender].push(paymentId);
        _receivedPayments[recipient].push(paymentId);

        emit PaymentEscrowed(paymentId, msg.sender, recipient, msg.value);
    }

    receive() external payable { revert("FinFlow: use sendPayment()"); }
    fallback() external payable { revert("FinFlow: invalid call"); }
}
