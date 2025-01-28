const RegistrarStorage = artifacts.require("RegistrarStorage");

contract("RegistrarStorage", (accounts) => {
  let registrarStorage;
  const owner = accounts[0];
  const registrar = accounts[1];
  const user = accounts[2];
  const safleId = "safleId1";
  const registrarName = "Registrar1";

  before(async () => {
    registrarStorage = await RegistrarStorage.deployed();
  });

  it("should set SafleId fees", async () => {
    const feeAmount = web3.utils.toWei("1", "ether");
    await registrarStorage.setSafleIdFees(feeAmount, { from: owner });
    const safleIdFees = await registrarStorage.safleIdFees();
    assert.equal(
      safleIdFees.toString(),
      feeAmount,
      "SafleId fees not set correctly"
    );
  });

  it("should register a registrar", async () => {
    const result = await registrarStorage.registerRegistrar(
      registrar,
      registrarName,
      { from: owner }
    );
    assert.equal(result.receipt.status, true, "Transaction failed"); // Check transaction status
    assert.equal(
      result.logs[0].event,
      "RegistrarRegistered",
      "Event not emitted"
    );

    const isRegistered = await registrarStorage.isRegisteredRegistrar(
      registrar
    );
    assert.equal(isRegistered, true, "Registrar not registered");
  });

  it("should register a SafleId", async () => {
    const safleId = "safleId1";
    const primaryAddress = accounts[2];

    // Step 1: Register the registrar (if not already registered)

    // Step 2: Prepare the message to sign
    const operation = "registerSafleId";
    const message = web3.utils.soliditySha3(
      web3.utils.toHex(operation),
      web3.utils.toHex(safleId),
      primaryAddress
    );

    // Step 3: Sign the message with the registrar's private key
    const signature = await web3.eth.sign(message, registrar);

    // Step 4: Call the function as the registrar
    const result = await registrarStorage.registerSafleId(
      safleId,
      registrar,
      primaryAddress,
      signature,
      { from: registrar }
    );

    // Step 5: Verify the SafleId is registered
    const primary = await registrarStorage.getPrimaryAddress(safleId);
    assert.equal(primary, primaryAddress, "SafleId not registered correctly");
  });

  it("should add a secondary address", async () => {
    const safleId = "safleId1";
    const primaryAddress = accounts[2];
    const secondaryAddress = accounts[3];
    const operation = "addSecondaryAddress";
    const message = web3.utils.soliditySha3(
      web3.utils.toHex(operation),
      web3.utils.toHex(safleId),
      primaryAddress
    );

    // Add secondary address
    const addSignature = await web3.eth.sign(message, primaryAddress);
    await registrarStorage.addSecondaryAddress(
      safleId,
      secondaryAddress,
      addSignature,
      { from: primaryAddress }
    );

    const isSecondary = await registrarStorage.isSecondaryAddress(
      safleId,
      secondaryAddress
    );
    assert.equal(isSecondary, true, "Secondary address not added");
  });

  it("should remove a secondary address", async () => {
    const safleId = "safleId1";
    const primaryAddress = accounts[2];
    const secondaryAddress = accounts[3];
    const operation = "removeSecondaryAddress";
    const message = web3.utils.soliditySha3(
      web3.utils.toHex(operation),
      web3.utils.toHex(safleId),
      primaryAddress
    );

    // Remove secondary address
    const removeSignature = await web3.eth.sign(message, primaryAddress);
    await registrarStorage.removeSecondaryAddress(
      safleId,
      secondaryAddress,
      removeSignature,
      { from: primaryAddress }
    );

    const isSecondary = await registrarStorage.isSecondaryAddress(
      safleId,
      secondaryAddress
    );
    assert.equal(isSecondary, false, "Secondary address not removed");
  });
  it("should update registrar name", async () => {
    const newRegistrarName = "NewRegistrar1";

    // Update the registrar name
    await registrarStorage.updateRegistrar(registrar, newRegistrarName, {
      from: registrar,
    });

    // Check if the name is updated
    const updatedName = await registrarStorage.registrarNames(registrar);

    assert.equal(updatedName, newRegistrarName, "Registrar name not updated");

    // Check if the event was emitted
    const events = await registrarStorage.getPastEvents("RegistrarUpdated", {
      fromBlock: 0,
    });

    assert.equal(
      events[0].returnValues.registrar,
      registrar,
      "Event registrar mismatch"
    );
    assert.equal(
      events[0].returnValues.oldName,
      registrarName,
      "Event oldName mismatch"
    );
    assert.equal(
      events[0].returnValues.newName,
      newRegistrarName,
      "Event newName mismatch"
    );
  });
});
