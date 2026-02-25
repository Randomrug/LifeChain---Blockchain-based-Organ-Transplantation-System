// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

contract OrganChain {

    // --- Roles ---
    mapping(address => bool) public isHospital;
    mapping(address => bool) public isTransporter;
    address public regulator;

    // --- Donors ---
    struct Donor {
        string organ;
        string blood;
        bool available;
    }
    mapping(uint256 => Donor) public donors;

    // --- Recipients ---
    struct Recipient {
        string organNeeded;
        string blood;
        uint256 urgency;
        uint256 waitingSince;
        bool active;
    }
    mapping(uint256 => Recipient) public recipients;
    uint256[] public recipientQueue;

    // --- Matching ---
    mapping(uint256 => uint256) public matches;   // donorId -> recipientId
    mapping(uint256 => bool) public completed;

    // --- Transport ---
    enum TransportState { None, Requested, PickedUp, InTransit, Delivered }
    struct TransportInfo {
        TransportState state;
        address transporter;
        uint256 timestamp;
    }
    mapping(uint256 => TransportInfo) public transports; // donorId -> transport

    // --- Events ---
    event MatchProposed(uint256 donorId, uint256 recipientId);
    event MatchFinalized(uint256 donorId, uint256 recipientId);
    event TransportStarted(uint256 donorId, address transporter);
    event TransportDelivered(uint256 donorId, address transporter);
    event SurgeryCompleted(uint256 donorId, uint256 recipientId);

    // --- Regulator ---
    function setRegulator(address _reg) external {
        regulator = _reg;
    }

    // --- Matching logic ---
    function computeScore(uint256 recipientId, Donor memory donor) internal view returns (uint256) {
        Recipient storage r = recipients[recipientId];
        uint256 score = r.urgency * 1e6 + (block.timestamp - r.waitingSince);
        if (keccak256(bytes(r.blood)) == keccak256(bytes(donor.blood))) {
            score += 1e9;
        }
        return score;
    }

    function _autoMatch(uint256 donorId) internal {
        require(donors[donorId].available, "donor not available");
        Donor memory d = donors[donorId];
        uint256 bestId = 0;
        uint256 bestScore = 0;
        for (uint i = 0; i < recipientQueue.length; i++) {
            uint256 rid = recipientQueue[i];
            if (!recipients[rid].active) continue;
            if (keccak256(bytes(recipients[rid].organNeeded)) != keccak256(bytes(d.organ))) continue;
            uint256 score = computeScore(rid, d);
            if (score > bestScore) {
                bestScore = score;
                bestId = rid;
            }
        }
        require(bestId > 0, "no compatible recipient");
        recipients[bestId].active = false;
        matches[donorId] = bestId;
        emit MatchProposed(donorId, bestId);
        emit MatchFinalized(donorId, bestId);
    }

    // --- Transport lifecycle ---
    function startTransport(uint256 donorId) external {
        require(isTransporter[msg.sender], "not transporter");
        require(matches[donorId] != 0, "no match");
        transports[donorId] = TransportInfo(TransportState.PickedUp, msg.sender, block.timestamp);
        emit TransportStarted(donorId, msg.sender);
    }

    function confirmDelivered(uint256 donorId) external {
        require(transports[donorId].transporter == msg.sender, "only assigned transporter");
        transports[donorId].state = TransportState.Delivered;
        emit TransportDelivered(donorId, msg.sender);
    }

    // --- Surgery lifecycle ---
    function markSurgeryComplete(uint256 donorId) external {
        require(isHospital[msg.sender], "only hospital");
        uint256 rid = matches[donorId];
        require(rid != 0, "no match");
        completed[donorId] = true;
        emit SurgeryCompleted(donorId, rid);
    }

    // --- Helper ---
    function getMatch(uint256 donorId) external view returns (uint256) {
        return matches[donorId];
    }
}
