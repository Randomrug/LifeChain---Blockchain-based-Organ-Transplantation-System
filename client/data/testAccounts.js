// Test accounts from your test file
const testAccounts = {
    tokenPool: "0xE628D1C5885cf856978146a50B601bA8835a0c54",
    hospitals: [
        "0x7f8e25Bf85f2DD8f25317886725acbC806101DC4",
        "0xcE478142B0Fd59b007Fab308a3A022DeF6B24Fa", 
        "0xA7613FAa3FEC7CCEAAB896729B8F49d11327858C"
    ],
    patient: "0x7da4F8324df7Ba120785fF2fC2649244EC1d562D"
};

// Contract deployment address - Replace with your actual deployed address
const deployedAddress = "0x086356a8EC7F2C069bEBE9e3D07fFaA57BaeF1b7";

// Sample patient data for demonstration
const samplePatientData = {
    "0x7da4F8324df7Ba120785fF2fC2649244EC1d562D": {
        name: "John Doe",
        bloodType: 3, // A+
        organNeeded: "Kidney",
        urgency: 2,
        registeredBy: "0x7f8e25Bf85f2DD8f25317886725acbC806101DC4",
        registeredAt: "2023-05-15T10:30:00Z"
    }
};

// Sample donor data for demonstration
const sampleDonorData = {
    1: {
        bloodType: 3, // A+
        organ: "Kidney",
        organQuality: "Excellent",
        registeredBy: "0xcE478142B0Fd59b007Fab308a3A022DeF6B24Fa",
        registeredAt: "2023-05-16T14:45:00Z"
    }
};

// Initialize sample data if localStorage is empty
function initializeSampleData() {
    if (!localStorage.getItem('data_initialized')) {
        // Store sample patient data
        Object.keys(samplePatientData).forEach(address => {
            localStorage.setItem(`patient_${address}`, JSON.stringify(samplePatientData[address]));
        });
        
        // Store sample donor data
        Object.keys(sampleDonorData).forEach(id => {
            localStorage.setItem(`donor_${id}`, JSON.stringify(sampleDonorData[id]));
        });
        
        localStorage.setItem('data_initialized', 'true');
    }
}

// Call initialization
initializeSampleData();