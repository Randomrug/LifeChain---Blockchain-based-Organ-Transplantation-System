const OrganDonation = artifacts.require("OrganDonation");

module.exports = async function(callback) {
  try {
    const accounts = await web3.eth.getAccounts();
    const contract = await OrganDonation.deployed();

    await contract.startTransport(1, { from: accounts[2] }); // hospital[2] dispatches
    console.log("Transport started for organ ID 1.");
  } catch (err) {
    console.error(err);
  }
  callback();
};
