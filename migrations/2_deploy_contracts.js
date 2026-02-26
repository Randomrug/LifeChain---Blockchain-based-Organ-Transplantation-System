// migrations/2_deploy_contracts.js

const OrganTransplant = artifacts.require("OrganTransplant");

module.exports = function (deployer, network, accounts) {
  
  // Argument 1: The transaction node address
  const transactionNode = accounts[4];

  // Argument 2: An array of hospital addresses
  const hospitals = [accounts[1], accounts[2], accounts[3]];

  // 👉 Pass all 2 arguments in the correct order
  deployer.deploy(OrganTransplant, transactionNode, hospitals);
};