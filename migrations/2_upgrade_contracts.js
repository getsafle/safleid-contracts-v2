const { deployProxy, upgradeProxy } = require("@openzeppelin/truffle-upgrades");

const RegistrarStorage = artifacts.require("RegistrarStorage");

const RegistrarStorageV2 = artifacts.require("RegistrarStorageV2");
module.exports = async function (deployer) {
  //   let registrarStorage = await RegistrarStorage.deployed();
  //   await upgradeProxy(registrarStorage.address, RegistrarStorageV2, {
  //     deployer,
  //   });
};
