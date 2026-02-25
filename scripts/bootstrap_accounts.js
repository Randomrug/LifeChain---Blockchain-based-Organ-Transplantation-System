const OrgToken = artifacts.require("OrgToken");
const OrganChain = artifacts.require("OrganChain");

module.exports = async function(callback) {
  try {
    const accounts = await web3.eth.getAccounts();
    const token = await OrgToken.deployed();
    const chain = await OrganChain.deployed();

    // mapping we will use in this MVP demo
    const TOKEN_POOL = accounts[0];
    const HOSPITALS = [accounts[1], accounts[2], accounts[3]]; // 3 hospitals
    const TRANSPORTER = accounts[4];
    const DONOR = accounts[11];
    const RECIPIENTS = [accounts[16], accounts[17], accounts[18]]; // 3 recipients

    const seedAmount = web3.utils.toWei('1000','ether');

    // Seed hospitals, transporter, donors/recipients from token pool
    for (const a of [...HOSPITALS, TRANSPORTER, DONOR, ...RECIPIENTS]) {
      await token.transfer(a, web3.utils.toWei('500','ether'), { from: TOKEN_POOL });
      console.log('seeded', a);
    }

    // Register roles on-chain
    for (const h of HOSPITALS) {
      await chain.addHospital(h, { from: TOKEN_POOL });
      console.log('added hospital', h);
    }

    await chain.addTransporter(TRANSPORTER, { from: TOKEN_POOL });
    console.log('added transporter', TRANSPORTER);

    // Finish execution
    callback();
  } catch (error) {
    console.error(error);
    callback(error);
  }
};
