const OrganDonation = artifacts.require("OrganDonation");

module.exports = async function(callback) {
  try {
    const accounts = await web3.eth.getAccounts();
    const contract = await OrganDonation.deployed();

    await contract.addOrganAvailable("Kidney", { from: accounts[8] });
    console.log("Organ listed as available.");
  } catch (err) {
    console.error(err);
  }
  callback();
};
