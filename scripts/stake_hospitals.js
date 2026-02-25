const OrganDonation = artifacts.require("OrganDonation");

module.exports = async function(callback) {
  try {
    const accounts = await web3.eth.getAccounts();
    const contract = await OrganDonation.deployed();

    // hospitals = accounts[1..3]
    for (let i = 1; i <= 3; i++) {
      await contract.stakeHospital({ from: accounts[i], value: web3.utils.toWei("10", "ether") });
      console.log(`Hospital staked: ${accounts[i]}`);
    }

  } catch (err) {
    console.error(err);
  }
  callback();
};
