const Checking = artifacts.require("checkingContract");
const RegistrarStorage = artifacts.require("RegistrarStorage");
module.exports = function (deployer) {
  deployer.deploy(Checking);
  deployer.deploy(RegistrarStorage);
};
