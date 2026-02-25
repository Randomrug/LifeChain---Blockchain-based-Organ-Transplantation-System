const OrganDonation = artifacts.require("OrganDonation");

module.exports = async function(callback) {
  try {
    const accounts = await web3.eth.getAccounts();
    const contract = await OrganDonation.deployed();

    // Register 3 patients (queue order)
    await contract.registerRecipient("Kidney", { from: accounts[5] });
    await contract.registerRecipient("Kidney", { from: accounts[6] });
    await contract.registerRecipient("Kidney", { from: accounts[7] });

    console.log("Recipients registered and added to queue.");
  } catch (err) {
    console.error(err);
  }
  callback();
};
