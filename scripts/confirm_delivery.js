const OrganDonation = artifacts.require("OrganDonation");

module.exports = async function(callback) {
  try {
    const accounts = await web3.eth.getAccounts();
    const contract = await OrganDonation.deployed();

    await contract.confirmDelivery(1, { from: accounts[3] }); // hospital[3] receives
    console.log("Delivery confirmed for organ ID 1.");
  } catch (err) {
    console.error(err);
  }
  callback();
};
