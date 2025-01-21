const checkingContract = artifacts.require("checkingContract");
const truffleAssert = require("truffle-assertions");

contract("checkingContract", (accounts) => {
  let checking;

  beforeEach(async () => {
    checking = await checkingContract.new();
  });
  //For the below tests to pass turn the method to public in contract
  describe("isContract", () => {
    it("should return true for contract addresses", async () => {
      // Deploy a second contract to test with
      const secondContract = await checkingContract.new();
      const result = await checking.isContract(secondContract.address);
      assert.equal(result, true, "Should identify contract address");
    });

    it("should return false for wallet addresses", async () => {
      const result = await checking.isContract(accounts[0]);
      assert.equal(result, false, "Should identify wallet address");
    });
  });

  describe("toLower", () => {
    it("should convert uppercase string to lowercase", async () => {
      const result = await checking.toLower("HELLO");
      assert.equal(result, "hello", "Should convert to lowercase");
    });

    it("should leave lowercase string unchanged", async () => {
      const result = await checking.toLower("hello");
      assert.equal(result, "hello", "Should leave lowercase unchanged");
    });

    it("should handle mixed case string", async () => {
      const result = await checking.toLower("HeLLo");
      assert.equal(result, "hello", "Should convert mixed case to lowercase");
    });
  });

  describe("checkLength", () => {
    it("should return correct string length", async () => {
      const result = await checking.checkLength("test");
      assert.equal(result, 4, "Should return correct length");
    });

    it("should revert for empty string", async () => {
      await truffleAssert.reverts(
        checking.checkLength(""),
        "Library : String passed is of zero length"
      );
    });
  });

  describe("checkAlphaNumeric", () => {
    it("should return true for alphanumeric string", async () => {
      const result = await checking.checkAlphaNumeric("abc123");
      assert.equal(result, true, "Should allow alphanumeric characters");
    });

    it("should return false for string with special characters", async () => {
      const result = await checking.checkAlphaNumeric("abc!23");
      assert.equal(result, false, "Should reject special characters");
    });

    it("should return false for string with spaces", async () => {
      const result = await checking.checkAlphaNumeric("abc 123");
      assert.equal(result, false, "Should reject spaces");
    });
  });

  //For the below tests to pass turn the method to public in contract
  describe("isSafleIdValid", () => {
    it("should return true for valid SafleId", async () => {
      const result = await checking.isSafleIdValid("test123");
      assert.equal(result, true, "Should accept valid SafleId");
    });

    it("should revert for SafleId shorter than 4 characters", async () => {
      await truffleAssert.reverts(
        checking.isSafleIdValid("abc"),
        "SafleId length should be between 4-16 characters"
      );
    });

    it("should revert for SafleId longer than 16 characters", async () => {
      await truffleAssert.reverts(
        checking.isSafleIdValid("abcdefghijklmnopq"),
        "SafleId length should be between 4-16 characters"
      );
    });

    it("should revert for non-alphanumeric SafleId", async () => {
      await truffleAssert.reverts(
        checking.isSafleIdValid("test@123"),
        "only alphanumeric allowed"
      );
    });

    it("should handle uppercase characters correctly", async () => {
      const result = await checking.isSafleIdValid("TEST123");
      assert.equal(result, true, "Should handle uppercase characters");
    });
  });
});
