const OrgToken = artifacts.require("OrgToken");
const OrganChain = artifacts.require("OrganChain");

module.exports = async function(deployer, network, accounts) {
  const initialSupply = web3.utils.toWei('1000','ether'); // 1000 tokens
  await deployer.deploy(OrgToken, initialSupply);

  const token = await OrgToken.deployed();
  await deployer.deploy(OrganChain, token.address);
  const chain = await OrganChain.deployed();

  // set regulator
  await chain.setRegulator(accounts[0]);
};
