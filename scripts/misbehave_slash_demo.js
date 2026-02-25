const OrganDonation = artifacts.require("OrganDonation");

module.exports = async function(callback) {
  try {
    const accounts = await web3.eth.getAccounts();
    const contract = await OrganDonation.deployed();

    // Hospital[2] misbehaves
    await contract.slashHospital(accounts[2], { from: accounts[0] }); // admin slashes
    console.log(`Hospital ${accounts[2]} slashed and tokens confiscated!`);
  } catch (err) {
    console.error(err);
  }
  callback();
};
