const Checking = artifacts.require("checkingContract");
module.exports = function (deployer) {
  deployer.deploy(Checking);
};
