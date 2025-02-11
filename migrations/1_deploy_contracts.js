const { deployProxy, upgradeProxy } = require("@openzeppelin/truffle-upgrades");
const Checking = artifacts.require("checkingContract");
const RegistrarStorage = artifacts.require("RegistrarStorage");
const RegistrarStorageV2 = artifacts.require("RegistrarStorageV2");
module.exports = async function (deployer) {
  deployer.deploy(Checking);
  let registrarStorage = await deployProxy(RegistrarStorage, [], {
    deployer,
    initializer: "initialize",
  });
  await upgradeProxy(registrarStorage.address, RegistrarStorageV2, {
    deployer,
  });
};
