// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title DeadManSwitch
/// @notice Multi-user inheritance contract. Lock ETH with a deadline; if you
///         miss your check-in, anyone can trigger payout to your beneficiary
///         and earn a small bounty for paying the gas.
/// @dev Fees auto-route to treasury on every fee-bearing tx — no claim() needed.
///      Treasury can lower fees but never above the immutable hard caps set at deploy.
contract DeadManSwitch {
    struct Switch {
        address depositor;
        address beneficiary;
        uint256 amount;
        uint64 pingInterval;
        uint64 lastPing;
        bool claimed;
    }

    Switch[] public switches;
    mapping(address => uint256[]) private _byDepositor;
    mapping(address => uint256[]) private _byBeneficiary;

    address public treasury;
    uint16 public registerFeeBps;
    uint16 public triggerBountyBps;

    uint16 public immutable maxRegisterFeeBps;
    uint16 public immutable maxTriggerBountyBps;
    uint64 public immutable minInterval;
    uint64 public immutable maxInterval;

    uint16 public constant BPS_DENOMINATOR = 10_000;

    event Registered(uint256 indexed id, address indexed depositor, address indexed beneficiary, uint256 locked, uint64 pingInterval, uint256 fee);
    event Pinged(uint256 indexed id, uint64 newDeadline);
    event ToppedUp(uint256 indexed id, uint256 added, uint256 fee);
    event BeneficiaryUpdated(uint256 indexed id, address indexed oldBeneficiary, address indexed newBeneficiary);
    event Cancelled(uint256 indexed id, uint256 refunded);
    event Triggered(uint256 indexed id, address indexed triggerer, uint256 bounty, uint256 toBeneficiary);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event FeesUpdated(uint16 registerFeeBps, uint16 triggerBountyBps);

    error NotDepositor();
    error NotTreasury();
    error AlreadyClaimed();
    error StillAlive();
    error IntervalOutOfRange();
    error ZeroValue();
    error ZeroAddress();
    error FeeAboveCap();
    error TransferFailed();

    modifier onlyDepositor(uint256 id) {
        if (switches[id].depositor != msg.sender) revert NotDepositor();
        _;
    }

    modifier onlyTreasury() {
        if (msg.sender != treasury) revert NotTreasury();
        _;
    }

    constructor(
        address _treasury,
        uint16 _registerFeeBps,
        uint16 _triggerBountyBps,
        uint16 _maxRegisterFeeBps,
        uint16 _maxTriggerBountyBps,
        uint64 _minInterval,
        uint64 _maxInterval
    ) {
        if (_treasury == address(0)) revert ZeroAddress();
        if (_maxRegisterFeeBps > BPS_DENOMINATOR / 2) revert FeeAboveCap();
        if (_maxTriggerBountyBps > BPS_DENOMINATOR / 2) revert FeeAboveCap();
        if (_registerFeeBps > _maxRegisterFeeBps) revert FeeAboveCap();
        if (_triggerBountyBps > _maxTriggerBountyBps) revert FeeAboveCap();
        if (_minInterval == 0 || _maxInterval < _minInterval) revert IntervalOutOfRange();

        treasury = _treasury;
        registerFeeBps = _registerFeeBps;
        triggerBountyBps = _triggerBountyBps;
        maxRegisterFeeBps = _maxRegisterFeeBps;
        maxTriggerBountyBps = _maxTriggerBountyBps;
        minInterval = _minInterval;
        maxInterval = _maxInterval;
    }

    function register(address beneficiary, uint64 pingInterval) external payable returns (uint256 id) {
        if (msg.value == 0) revert ZeroValue();
        if (beneficiary == address(0)) revert ZeroAddress();
        if (pingInterval < minInterval || pingInterval > maxInterval) revert IntervalOutOfRange();

        uint256 fee = (msg.value * registerFeeBps) / BPS_DENOMINATOR;
        uint256 locked = msg.value - fee;

        id = switches.length;
        switches.push(Switch({
            depositor: msg.sender,
            beneficiary: beneficiary,
            amount: locked,
            pingInterval: pingInterval,
            lastPing: uint64(block.timestamp),
            claimed: false
        }));
        _byDepositor[msg.sender].push(id);
        _byBeneficiary[beneficiary].push(id);

        emit Registered(id, msg.sender, beneficiary, locked, pingInterval, fee);

        if (fee > 0) _send(treasury, fee);
    }

    function ping(uint256 id) external onlyDepositor(id) {
        Switch storage s = switches[id];
        if (s.claimed) revert AlreadyClaimed();
        s.lastPing = uint64(block.timestamp);
        emit Pinged(id, uint64(block.timestamp) + s.pingInterval);
    }

    function topUp(uint256 id) external payable onlyDepositor(id) {
        if (msg.value == 0) revert ZeroValue();
        Switch storage s = switches[id];
        if (s.claimed) revert AlreadyClaimed();

        uint256 fee = (msg.value * registerFeeBps) / BPS_DENOMINATOR;
        uint256 added = msg.value - fee;
        s.amount += added;
        s.lastPing = uint64(block.timestamp);

        emit ToppedUp(id, added, fee);

        if (fee > 0) _send(treasury, fee);
    }

    function setBeneficiary(uint256 id, address newBeneficiary) external onlyDepositor(id) {
        if (newBeneficiary == address(0)) revert ZeroAddress();
        Switch storage s = switches[id];
        if (s.claimed) revert AlreadyClaimed();
        address old = s.beneficiary;
        s.beneficiary = newBeneficiary;
        _byBeneficiary[newBeneficiary].push(id);
        emit BeneficiaryUpdated(id, old, newBeneficiary);
    }

    function cancel(uint256 id) external onlyDepositor(id) {
        Switch storage s = switches[id];
        if (s.claimed) revert AlreadyClaimed();
        uint256 refund = s.amount;
        s.amount = 0;
        s.claimed = true;
        emit Cancelled(id, refund);
        _send(msg.sender, refund);
    }

    function trigger(uint256 id) external {
        Switch storage s = switches[id];
        if (s.claimed) revert AlreadyClaimed();
        if (block.timestamp <= uint256(s.lastPing) + uint256(s.pingInterval)) revert StillAlive();

        uint256 amount = s.amount;
        uint256 bounty = (amount * triggerBountyBps) / BPS_DENOMINATOR;
        uint256 toBeneficiary = amount - bounty;
        address beneficiary = s.beneficiary;

        s.amount = 0;
        s.claimed = true;

        emit Triggered(id, msg.sender, bounty, toBeneficiary);

        if (bounty > 0) _send(msg.sender, bounty);
        if (toBeneficiary > 0) _send(beneficiary, toBeneficiary);
    }

    function setFees(uint16 newRegisterFeeBps, uint16 newTriggerBountyBps) external onlyTreasury {
        if (newRegisterFeeBps > maxRegisterFeeBps) revert FeeAboveCap();
        if (newTriggerBountyBps > maxTriggerBountyBps) revert FeeAboveCap();
        registerFeeBps = newRegisterFeeBps;
        triggerBountyBps = newTriggerBountyBps;
        emit FeesUpdated(newRegisterFeeBps, newTriggerBountyBps);
    }

    function setTreasury(address newTreasury) external onlyTreasury {
        if (newTreasury == address(0)) revert ZeroAddress();
        address old = treasury;
        treasury = newTreasury;
        emit TreasuryUpdated(old, newTreasury);
    }

    function deadline(uint256 id) external view returns (uint64) {
        Switch storage s = switches[id];
        return s.lastPing + s.pingInterval;
    }

    function isAlive(uint256 id) external view returns (bool) {
        Switch storage s = switches[id];
        if (s.claimed) return false;
        return block.timestamp <= uint256(s.lastPing) + uint256(s.pingInterval);
    }

    function totalSwitches() external view returns (uint256) {
        return switches.length;
    }

    function switchesByDepositor(address depositor) external view returns (uint256[] memory) {
        return _byDepositor[depositor];
    }

    function switchesByBeneficiary(address beneficiary) external view returns (uint256[] memory) {
        return _byBeneficiary[beneficiary];
    }

    function _send(address to, uint256 amount) private {
        (bool ok, ) = to.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }
}
