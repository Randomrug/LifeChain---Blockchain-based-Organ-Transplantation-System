const OrganTransplant = artifacts.require("OrganTransplant");
const truffleAssert = require('truffle-assertions');

contract("OrganTransplant: Simplified Workflow (No Stake)", (accounts) => {

    // --- Define Roles ---
    const owner = accounts[0];
    const transactionNode = accounts[2];
    const donorHospitalAddr = accounts[3];
    const recipientHospitalAddr = accounts[4];
    const otherHospitalAddr = accounts[5];
    const patientAddr = accounts[6];
    const unregisteredAddr = accounts[7];

    // --- Contract-Wide Variables ---
    let organTransplant;
// Make SURE these lines look exactly like this:
const organKidney = web3.utils.asciiToHex("Kidney");
const organLiver = web3.utils.asciiToHex("Liver");

    beforeEach(async () => {
        const hospitalArray = [donorHospitalAddr, recipientHospitalAddr, otherHospitalAddr];
        // --- UPDATED: Deploy with 2 arguments ---
        organTransplant = await OrganTransplant.new(
            transactionNode, 
            hospitalArray, 
            { from: owner }
        );
    });

    // --- Test 1: Deployment & Initialization ---
    it("should deploy with correct initial values", async () => {
        const node = await organTransplant.transactionNode();
        const hospitalCount = await organTransplant.getHospitalCount();

        assert.equal(node, transactionNode, "TransactionNode address is incorrect");
        assert.equal(hospitalCount.toString(), "3", "Hospital count should be 3 on deploy");
    });

    // --- REMOVED: Staking test ---

    // --- Test 2: Registration ---
    it("should allow registered hospitals to register patients and donors", async () => {
        // No stake needed
        await organTransplant.registerPatient(patientAddr, 1, organKidney, { from: donorHospitalAddr });
        const patient = await organTransplant.patients(patientAddr);

        assert.equal(patient.organNeeded, organKidney, "Patient's organ does not match");
        assert.equal(patient.status.toString(), "0", "Patient status should be 'Waiting'");

        await organTransplant.registerDonor(2, organLiver, { from: donorHospitalAddr });
        const donor = await organTransplant.donors(1); 
        assert.equal(donor.organ, organLiver, "Donor's organ does not match");
    });
    
    // --- Test 3: Access Control & Reverts ---
    it("should fail transactions with incorrect roles", async () => {
        // --- UPDATED: Removed staking check ---
        
        // 1. Unregistered address (e.g., a patient) tries to register a patient
        await truffleAssert.reverts(
            organTransplant.registerPatient(patientAddr, 1, organKidney, { from: unregisteredAddr }),
            "Not a registered hospital"
        );
        
        // 2. Patient tries to call a hospital function
        await truffleAssert.reverts(
            organTransplant.registerDonor(1, organKidney, { from: patientAddr }),
            "Not a registered hospital"
        );
    });

    // --- Test 4: The "Happy Path" - Full Workflow ---
    it("should complete the full transplant workflow from match to confirmation", async () => {
        // --- 1. SETUP: Hospitals are active on deploy ---
        const hospitalCount = await organTransplant.getHospitalCount();
        assert.equal(hospitalCount.toString(), "3", "Should have 3 hospitals");
        
        // --- 2. REGISTRATION ---
        await organTransplant.registerPatient(patientAddr, 1, organKidney, { from: recipientHospitalAddr });
        await organTransplant.registerDonor(1, organKidney, { from: donorHospitalAddr }); 
        
        // --- 3. MATCHING ---
        await organTransplant.createMatch(1, patientAddr, { from: donorHospitalAddr });
        let patient = await organTransplant.patients(patientAddr);
        assert.equal(patient.status.toString(), "1", "Patient status should be 'Matched'"); 

        // --- 4. PATIENT PRE-APPROVAL ---
        await organTransplant.patientPreApprove(1, { from: patientAddr });
        patient = await organTransplant.patients(patientAddr);
        assert.equal(patient.status.toString(), "2", "Patient status should be 'PatientApproved'"); 

        // --- 5. VOTING (Need 2 of 3) ---
        await organTransplant.initiateAndVote(1, true, { from: donorHospitalAddr });
        await organTransplant.initiateAndVote(1, true, { from: otherHospitalAddr });
        let match = await organTransplant.matches(1);
        assert.equal(match.yesVotes.toString(), "2", "Should have 2 yes votes");

        // --- 6. PATIENT FINAL ACCEPTANCE (Tests vote logic) ---
        await organTransplant.patientAccept(1, { from: patientAddr });
        patient = await organTransplant.patients(patientAddr);
        let logistics = await organTransplant.logistics(1);
        
        assert.equal(patient.status.toString(), "3", "Patient status should be 'MedicallyApproved'"); 
        assert.equal(logistics.status.toString(), "1", "Logistics status should be 'AwaitingPickupApproval'"); 

        // --- 7. LOGISTICS DOUBLE-HANDSHAKE ---
        await organTransplant.donorHospitalConfirmReady(1, { from: donorHospitalAddr });
        await organTransplant.transactionNodeConfirmPickup(1, { from: transactionNode });
        await organTransplant.donorHospitalConfirmNodePickup(1, { from: donorHospitalAddr });
        await organTransplant.transactionNodeConfirmDelivery(1, { from: transactionNode });

        // --- 8. FINAL CONFIRMATION ---
        await organTransplant.recipientHospitalConfirmReceipt(1, { from: recipientHospitalAddr });
        patient = await organTransplant.patients(patientAddr);
        logistics = await organTransplant.logistics(1);

        assert.equal(logistics.status.toString(), "6", "Logistics status should be 'ConfirmedByRecipient'"); 
        assert.equal(patient.status.toString(), "4", "Patient status should be 'Completed'"); 
    });

    // --- Test 5: The "Rejection Path" ---
    it("should allow a recipient hospital to reject a delivery", async () => {
        // --- Abbreviated Setup ---
        await organTransplant.registerPatient(patientAddr, 1, organKidney, { from: recipientHospitalAddr });
        await organTransplant.registerDonor(1, organKidney, { from: donorHospitalAddr });
        await organTransplant.createMatch(1, patientAddr, { from: donorHospitalAddr });
        await organTransplant.patientPreApprove(1, { from: patientAddr }); 
        await organTransplant.initiateAndVote(1, true, { from: donorHospitalAddr });
        await organTransplant.initiateAndVote(1, true, { from: recipientHospitalAddr }); 
        await organTransplant.patientAccept(1, { from: patientAddr });
        await organTransplant.donorHospitalConfirmReady(1, { from: donorHospitalAddr });
        await organTransplant.transactionNodeConfirmPickup(1, { from: transactionNode });
        await organTransplant.donorHospitalConfirmNodePickup(1, { from: donorHospitalAddr });
        await organTransplant.transactionNodeConfirmDelivery(1, { from: transactionNode });
        // --- End Setup ---

        // --- 7. REJECTION ---
        await organTransplant.recipientHospitalRejectDelivery(1, { from: recipientHospitalAddr });
        
        const logistics = await organTransplant.logistics(1);
        const patient = await organTransplant.patients(patientAddr);

        assert.equal(logistics.status.toString(), "7", "Logistics status should be 'DeliveryRejected'"); 
        assert.equal(patient.status.toString(), "3", "Patient status should remain 'MedicallyApproved'");
    });
});