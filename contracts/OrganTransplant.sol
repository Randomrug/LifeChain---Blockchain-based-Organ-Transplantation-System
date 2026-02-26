// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

contract OrganTransplant {
    // --- Enums ---
    enum Status { Waiting, Matched, PatientApproved, MedicallyApproved, Completed }
    
    enum LogisticsStatus {
        Inactive,
        AwaitingPickupApproval,
        ReadyForPickup,
        AwaitingPickupConfirmation,
        InTransit,
        Delivered,
        ConfirmedByRecipient,
        DeliveryRejected
    }

    // --- Structs ---
    struct Hospital { 
        address addr; 
        bool exists;
        uint trustNumerator;   // NEW: For trust score
        uint trustDenominator; // NEW: For trust score
    }
    
    struct Patient { 
        address addr; 
        uint8 bloodType; 
        bytes32 organNeeded; 
        Status status; 
        address registeredBy; 
    }
    
    struct Donor { 
        uint256 id; 
        address registeredBy; 
        uint8 bloodType; 
        bytes32 organ; 
        Status status; 
    }
    
    struct Match { 
        uint256 matchId; 
        uint256 donorId; 
        address patient; 
        uint256 yesVotes; 
        // MODIFIED: Store the actual vote (0=NotVoted, 1=Yes, 2=No)
        mapping(address => uint8) vote; 
        bool validationInitiated; 
        bool completed; 
    }
    
    struct Logistics { 
        address donorHospital;
        LogisticsStatus status;
        address recipientHospital;
        uint256 matchId;
    }

    // NEW: Struct for proposing new hospitals
    struct HospitalProposal {
        address addr;
        uint yesVotes;
        mapping(address => bool) voted;
        bool exists;
        bool completed;
    }
    
    // --- State Variables ---
    address public owner;
    address public transactionNode;
    address[] public hospitalAddresses;
    address[] public hospitalProposalList; // NEW: To iterate proposals

    mapping(address => Hospital) public hospitals;
    mapping(address => Patient) public patients;
    mapping(uint256 => Donor) public donors;
    mapping(uint256 => Match) public matches;
    mapping(uint256 => Logistics) public logistics;
    mapping(address => HospitalProposal) public hospitalProposals; // NEW
    
    uint256 public donorCounter;
    uint256 public matchCounter;

    // --- Events ---
    event PatientRegistered(address indexed patient, bytes32 organ, address indexed registeredBy);
    event DonorRegistered(uint256 indexed donorId, bytes32 organ, address indexed registeredBy);
    event MatchCreated(uint256 indexed matchId, uint256 indexed donorId, address indexed patient);
    event PatientApproved(uint256 indexed matchId);
    event VoteCast(uint256 indexed matchId, address indexed voter, bool approved);
    event TransferMedicallyApproved(uint256 indexed matchId);
    event LogisticsInitiated(uint256 indexed matchId, address donorHospital, address recipientHospital);
    event OrganReadyForPickup(uint256 indexed matchId);
    event OrganPickedUpByNode(uint256 indexed matchId);
    event NodePickupConfirmedByHospital(uint256 indexed matchId);
    event OrganDelivered(uint256 indexed matchId);
    event OrganReceiptConfirmed(uint256 indexed matchId);
    event DeliveryRejected(uint256 indexed matchId);
    event HospitalProposed(address indexed newHospital, address indexed proposedBy); // NEW
    event HospitalVoteCast(address indexed newHospital, address indexed voter, bool approved); // NEW
    event HospitalAdded(address indexed newHospital); // NEW
    event TrustScoreUpdated(address indexed hospital, uint numerator, uint denominator); // NEW

    // --- Constructor ---
    constructor(address _transactionNode, address[] memory _hospitals) {
        owner = msg.sender;
        transactionNode = _transactionNode;
        for (uint i = 0; i < _hospitals.length; i++) {
            require(_hospitals[i] != address(0), "Invalid hospital address");
            hospitalAddresses.push(_hospitals[i]);
            // NEW: Initial hospitals start with a 10/10 trust score
            hospitals[_hospitals[i]] = Hospital(_hospitals[i], true, 10, 10); 
        }
    }
    
    // --- Modifiers ---
    modifier onlyOwner() { require(msg.sender == owner, "Only owner"); _; }
    modifier onlyHospital() { require(hospitals[msg.sender].exists, "Not a registered hospital"); _; }
    modifier onlyTransactionNode() { require(msg.sender == transactionNode, "Not the transaction node"); _; }

    // --- Hospital Management (NEW) ---

    function proposeHospital(address _newHospital) public onlyOwner {
        require(_newHospital != address(0), "Invalid address");
        require(!hospitals[_newHospital].exists, "Hospital already registered");
        require(!hospitalProposals[_newHospital].exists, "Proposal already pending");

        // --- THIS IS THE FIX ---
        // Get a storage pointer to the new proposal slot
        HospitalProposal storage newProposal = hospitalProposals[_newHospital];

        // Initialize its members individually
        newProposal.addr = _newHospital;
        newProposal.yesVotes = 0;
        newProposal.exists = true;
        newProposal.completed = false;
        // The 'voted' mapping is automatically empty, so no need to set it.
        // --- END OF FIX ---

        hospitalProposalList.push(_newHospital);
        emit HospitalProposed(_newHospital, msg.sender);
    }

    function voteOnHospital(address _newHospital, bool _approve) public onlyHospital {
        HospitalProposal storage proposal = hospitalProposals[_newHospital];
        require(proposal.exists, "No proposal for this address");
        require(!proposal.completed, "Vote already completed");
        require(!proposal.voted[msg.sender], "Hospital already voted");

        proposal.voted[msg.sender] = true;
        if (_approve) {
            proposal.yesVotes++;
        }
        emit HospitalVoteCast(_newHospital, msg.sender, _approve);

        // Check for 2/3rds majority to approve
        uint totalHospitals = hospitalAddresses.length;
        if (proposal.yesVotes * 3 >= totalHospitals * 2) {
            proposal.completed = true;
            // NEW: Add new hospital with 5/10 "probationary" score
            hospitals[_newHospital] = Hospital(_newHospital, true, 5, 10);
            hospitalAddresses.push(_newHospital);
            emit HospitalAdded(_newHospital);
        }
    }
    // --- Getter Functions ---

    // NEW: Getter for hospital proposal voting status
    function getProposalVoteStatus(address _proposalAddr, address _hospitalAddr) public view returns (bool) {
        return hospitalProposals[_proposalAddr].voted[_hospitalAddr];
    }
    
    
    // --- Registration Functions ---
    
    function registerPatient(address _patient, uint8 _bloodType, bytes32 _organNeeded) public onlyHospital {
        require(patients[_patient].addr == address(0), "Patient already exists");
        patients[_patient] = Patient(_patient, _bloodType, _organNeeded, Status.Waiting, msg.sender);
        emit PatientRegistered(_patient, _organNeeded, msg.sender);
    }
    
    function registerDonor(uint8 _bloodType, bytes32 _organ) public onlyHospital {
        donorCounter++;
        donors[donorCounter] = Donor(donorCounter, msg.sender, _bloodType, _organ, Status.Waiting);
        emit DonorRegistered(donorCounter, _organ, msg.sender);
    }

    // --- Match & Vote Logic ---

    function createMatch(uint256 _donorId, address _patient) public onlyHospital {
        require(donors[_donorId].status == Status.Waiting, "Donor not available");
        require(patients[_patient].status == Status.Waiting, "Patient not available");
        require(donors[_donorId].organ == patients[_patient].organNeeded, "Organ type mismatch");

        matchCounter++;
        Match storage newMatch = matches[matchCounter];
        newMatch.matchId = matchCounter;
        newMatch.donorId = _donorId;
        newMatch.patient = _patient;
        donors[_donorId].status = Status.Matched;
        patients[_patient].status = Status.Matched;
        emit MatchCreated(matchCounter, _donorId, _patient);
    }

    function patientPreApprove(uint256 _matchId) public {
        Match storage currentMatch = matches[_matchId];
        require(msg.sender == currentMatch.patient, "Not the patient");
        require(patients[msg.sender].status == Status.Matched, "Match not in correct state");
        patients[msg.sender].status = Status.PatientApproved;
        emit PatientApproved(_matchId);
    }
    
    // MODIFIED: Use the new `vote` mapping
    function initiateAndVote(uint256 _matchId, bool _approve) public onlyHospital {
        Match storage currentMatch = matches[_matchId];
        require(patients[currentMatch.patient].status == Status.PatientApproved, "Patient has not pre-approved");
        require(currentMatch.vote[msg.sender] == 0, "Already voted"); // Check vote == 0
        
        currentMatch.validationInitiated = true;
        currentMatch.vote[msg.sender] = _approve ? 1 : 2; // Set vote to 1 (Yes) or 2 (No)

        if (_approve) { 
            currentMatch.yesVotes++; 
        }
        emit VoteCast(_matchId, msg.sender, _approve);
    }
    
    function patientAccept(uint256 _matchId) public {
        Match storage currentMatch = matches[_matchId];
        require(msg.sender == currentMatch.patient, "Not the patient");
        require(!currentMatch.completed, "Transfer already completed");
        
        uint totalHospitals = hospitalAddresses.length;
        require(currentMatch.yesVotes > 0 && totalHospitals > 0, "No votes or no hospitals");
        require(currentMatch.yesVotes * 3 >= totalHospitals * 2, "Insufficient votes");
        
        currentMatch.completed = true;
        patients[currentMatch.patient].status = Status.MedicallyApproved;
        donors[currentMatch.donorId].status = Status.MedicallyApproved;
        
        address donorHosp = donors[currentMatch.donorId].registeredBy;
        address recipientHosp = patients[currentMatch.patient].registeredBy;
        
        logistics[_matchId] = Logistics(donorHosp, LogisticsStatus.AwaitingPickupApproval, recipientHosp, _matchId);
        
        emit TransferMedicallyApproved(_matchId);
        emit LogisticsInitiated(_matchId, donorHosp, recipientHosp);
    }
    
    // --- Logistics Functions ---

    function donorHospitalConfirmReady(uint256 _matchId) public onlyHospital {
        Logistics storage l = logistics[_matchId];
        require(l.status == LogisticsStatus.AwaitingPickupApproval, "Not awaiting pickup approval");
        require(l.donorHospital == msg.sender, "Not the donor's hospital");
        l.status = LogisticsStatus.ReadyForPickup;
        emit OrganReadyForPickup(_matchId);
    }

    function transactionNodeConfirmPickup(uint256 _matchId) public onlyTransactionNode {
        Logistics storage l = logistics[_matchId];
        require(l.status == LogisticsStatus.ReadyForPickup, "Not ready for pickup");
        l.status = LogisticsStatus.AwaitingPickupConfirmation;
        emit OrganPickedUpByNode(_matchId);
    }

    function donorHospitalConfirmNodePickup(uint256 _matchId) public onlyHospital {
        Logistics storage l = logistics[_matchId];
        require(l.status == LogisticsStatus.AwaitingPickupConfirmation, "Node has not confirmed pickup yet");
        require(l.donorHospital == msg.sender, "Not the donor's hospital");
        l.status = LogisticsStatus.InTransit;
        emit NodePickupConfirmedByHospital(_matchId);
    }

    function transactionNodeConfirmDelivery(uint256 _matchId) public onlyTransactionNode {
        Logistics storage l = logistics[_matchId];
        require(l.status == LogisticsStatus.InTransit, "Not in transit");
        l.status = LogisticsStatus.Delivered;
        emit OrganDelivered(_matchId);
    }

    // MODIFIED: Added trust score logic
    function recipientHospitalConfirmReceipt(uint256 _matchId) public onlyHospital {
        Logistics storage l = logistics[_matchId];
        require(l.status == LogisticsStatus.Delivered, "Not yet delivered");
        require(l.recipientHospital == msg.sender, "Not the recipient's hospital");
        
        l.status = LogisticsStatus.ConfirmedByRecipient;
        patients[matches[_matchId].patient].status = Status.Completed;
        donors[matches[_matchId].donorId].status = Status.Completed;
        
        // --- NEW: Update trust scores (Success) ---
        updateScores(_matchId, true);

        emit OrganReceiptConfirmed(_matchId);
    }

    // MODIFIED: Added trust score logic
    function recipientHospitalRejectDelivery(uint256 _matchId) public onlyHospital {
        Logistics storage l = logistics[_matchId];
        require(l.status == LogisticsStatus.Delivered, "Not yet delivered");
        require(l.recipientHospital == msg.sender, "Not the recipient's hospital");
        l.status = LogisticsStatus.DeliveryRejected;

        // --- NEW: Update trust scores (Failure) ---
        updateScores(_matchId, false);

        emit DeliveryRejected(_matchId);
    }
    
    // --- Internal Score Helper (NEW) ---
    function updateScores(uint256 _matchId, bool _success) internal {
        Match storage currentMatch = matches[_matchId];
        
        for (uint i = 0; i < hospitalAddresses.length; i++) {
            address hospitalAddr = hospitalAddresses[i];
            uint8 vote = currentMatch.vote[hospitalAddr]; // 0=NV, 1=Yes, 2=No
            
            if (vote == 1) { // Voted Yes
                if (_success) { // Voted Yes, was Success (Correct)
                    hospitals[hospitalAddr].trustNumerator++;
                    hospitals[hospitalAddr].trustDenominator++;
                } else { // Voted Yes, was Failure (Incorrect)
                    hospitals[hospitalAddr].trustDenominator++;
                }
                emit TrustScoreUpdated(hospitalAddr, hospitals[hospitalAddr].trustNumerator, hospitals[hospitalAddr].trustDenominator);
            } else if (vote == 2) { // Voted No
                if (_success) { // Voted No, was Success (Incorrect)
                    hospitals[hospitalAddr].trustDenominator++;
                } else { // Voted No, was Failure (Correct)
                    hospitals[hospitalAddr].trustNumerator++;
                    hospitals[hospitalAddr].trustDenominator++;
                }
                emit TrustScoreUpdated(hospitalAddr, hospitals[hospitalAddr].trustNumerator, hospitals[hospitalAddr].trustDenominator);
            }
            // If vote == 0 (No Vote), score is unchanged
        }
    }

    // --- Getter Functions ---
    function hasHospitalVoted(uint256 _matchId, address _hospital) public view returns (bool) { 
        return matches[_matchId].vote[_hospital] != 0; // MODIFIED
    }
    
    function getDonorCount() public view returns (uint256) { 
        return donorCounter; 
    }

    function getHospitalCount() public view returns (uint) {
        return hospitalAddresses.length;
    }

    // NEW: Getter for pending proposals
    function getPendingProposals() public view returns (address[] memory) {
        uint count = 0;
        for (uint i = 0; i < hospitalProposalList.length; i++) {
            if (!hospitalProposals[hospitalProposalList[i]].completed) {
                count++;
            }
        }
        
        address[] memory pending = new address[](count);
        uint index = 0;
        for (uint i = 0; i < hospitalProposalList.length; i++) {
            address proposalAddr = hospitalProposalList[i];
            if (!hospitalProposals[proposalAddr].completed) {
                pending[index] = proposalAddr;
                index++;
            }
        }
        return pending;
    }
}