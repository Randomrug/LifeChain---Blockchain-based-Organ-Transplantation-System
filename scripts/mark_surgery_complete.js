const OrganDonation = artifacts.require("OrganDonation");

module.exports = async function(callback) {
  try {
    const accounts = await web3.eth.getAccounts();
    const contract = await OrganDonation.deployed();

    await contract.markSurgeryComplete(1, { from: accounts[5] }); // recipient[5] gets surgery
    console.log("Surgery completed for recipient.");
  } catch (err) {
    console.error(err);
  }
  callback();
};
