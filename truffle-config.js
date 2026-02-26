/*module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",     // Ganache GUI Quickstart default
      port: 7545,            // Ganache RPC port
      network_id: "*",       // Match any network id
    },
  },

  compilers: {
    solc: {
      version: "0.7.3",     // matches your Migrations.sol compiler version
    },
  },
};
*/

module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "*" // Match any network id
    }
  },
  compilers: {
    solc: {
      version: "0.7.3",
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        }
      }
    }
  }
};