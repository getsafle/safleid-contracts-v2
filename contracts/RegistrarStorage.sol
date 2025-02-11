// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./checkingContract.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
contract RegistrarStorage is  UUPSUpgradeable ,OwnableUpgradeable, checkingContract {
    
    struct UserData {
        address primary;
        mapping(address => bool) isSecondary;
        address[] secondaries;
        bool exists;
    }

    struct Registrar {
        bool isRegisteredRegistrar;
        string registrarName;
        address registrarAddress;
    }

    struct OtherCoin {
        string coinName;
        string aliasName;
        bool isIndexMapped;
    }
    
    uint256 public registrarFees;
    uint256 public safleIdFees;
    address public contractOwner;
    address payable public walletAddress;
    uint256 public MAX_NAME_UPDATES ;
    bool public safleIdRegStatus;
    bool public isPaused;

    uint256 public totalRegistrars;
    uint256 public totalSafleIdRegistered;
    
    // Registrar-related mappings
    mapping(address => bool) public isRegisteredRegistrar;
    mapping(address => string) public registrarNames;
    mapping(string => address) public registrarNameToAddress;
    mapping(address => uint8) public totalRegistrarUpdates;
    mapping(address => uint8) public totalRegistrarNameUpdates;
    mapping(address => uint8) public totalSafleIDCount;
    mapping(address => bytes[]) public resolveOldRegistrarAddress;
    mapping(address => Registrar) public Registrars;
    
    // User and SafleID mappings
    mapping(string => UserData) private userAddresses;
    mapping(string => bool) public unavailableSafleIds;
    string[] public registeredSafleIds;
    
    // Mappings to manage the SafleID functionalities
    mapping(bytes => address) public resolveAddressFromSafleId;
    mapping(address => bool) public isAddressTaken;
    mapping(address => string) public resolveUserAddress;
    mapping(address => bytes[]) public resolveOldSafleIdFromAddress;
    mapping(bytes => address) public resolveOldSafleID;

    // Events
    event SecondaryAddressAdded(string indexed safleId, address secondary);
    event SecondaryAddressRemoved(string indexed safleId, address secondary);
    event RegistrarRegistered(address indexed registrar, string registrarName);
    event RegistrarUpdated(address indexed registrar, string oldName, string newName);

    string constant PREFIX = "\x19Ethereum Signed Message:\n32";
    
    // Modifiers


    modifier safleIdExists(string memory _safleId) {
        require(userAddresses[_safleId].exists, "SafleID does not exist");
        _;
    }

    modifier WhenNotPaused(){
        require(isPaused==false, "Contract is Paused");
        _;
    }

    modifier safleIdDoesNotExist(string memory _safleId) {
        require(!userAddresses[_safleId].exists, "SafleID already exists");
        require(!unavailableSafleIds[_safleId], "SafleID not available");
        _;
    }

    modifier registrarChecks(string memory _registrarName) {
        bytes memory regNameBytes = bytes(_registrarName);
        require(registrarNameToAddress[string(regNameBytes)] == address(0x0), "Registrar name is already taken.");
        require(resolveAddressFromSafleId[regNameBytes] == address(0x0), "This Registrar name is already registered as a SafleID.");
        _;
    }

    modifier safleIdChecks(string memory _safleId, address _registrar) {
        bytes memory idBytes = bytes(_safleId);
        require(Registrars[_registrar].registrarAddress != address(0x0), "Invalid Registrar.");
        require(registrarNameToAddress[string(idBytes)] == address(0x0), "This SafleId is taken by a Registrar.");
        require(resolveAddressFromSafleId[idBytes] == address(0x0), "This SafleId is already registered.");
        require(unavailableSafleIds[_safleId] == false, "SafleId is already used once, not available now");
        _;
    }

    // Signature verification modifiers
    modifier verifyPrimarySignature(
        string memory _safleId,
        address _primaryAddress,
        bytes memory _signature,
        string memory _operation
    ) {
        bytes memory data = abi.encodePacked(_operation, _safleId, _primaryAddress);
        require(verifySignature(data, _primaryAddress, _signature), "Invalid user signature");
        _;
    }
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    // Constructor
    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
       MAX_NAME_UPDATES = 3;
    }
   
    // Existing signature verification functions from first contract
    function getMessageHash(bytes memory _data) public pure returns (bytes32) {
        return keccak256(_data);
    }

    function getEthSignedMessageHash(bytes32 _messageHash) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(PREFIX, _messageHash));
    }

    function recoverSigner(bytes32 _ethSignedMessageHash, bytes memory _signature) public pure returns (address) {
        require(_signature.length == 65, "Invalid signature length");

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(_signature, 32))
            s := mload(add(_signature, 64))
            v := byte(0, mload(add(_signature, 96)))
        }

        if (v < 27) {
            v += 27;
        }

        require(v == 27 || v == 28, "Invalid signature 'v' value");

        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    function verifySignature(
        bytes memory _data,
        address _expectedSigner,
        bytes memory _signature
    ) public pure returns (bool) {
        bytes32 messageHash = getMessageHash(_data);
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        address signer = recoverSigner(ethSignedMessageHash, _signature);
        return signer == _expectedSigner;
    }

    // Owner functions for chain management
    function setSafleIdFees(uint256 _amount) public WhenNotPaused onlyOwner {
        require(_amount >= 0, "Please set a fee for SafleID registration.");
        safleIdFees = _amount;
    }

    function setRegistrarFees(uint256 _amount) public WhenNotPaused onlyOwner {
        require(_amount >= 0, "Please set a fee for Registrar registration.");
        registrarFees = _amount;
    }

    function updateWalletAddress(address payable _walletAddress) public WhenNotPaused onlyOwner {
        require(!isContract(_walletAddress), "Wallet address cannot be a contract");
        walletAddress = _walletAddress;
    }

    function toggleRegistrationStatus() external WhenNotPaused onlyOwner returns (bool) {
        safleIdRegStatus = !safleIdRegStatus;
        return true;
    }

    // Registrar registration and update functions
    function registerRegistrar(address _registrar, string calldata _registrarName)
        external
        WhenNotPaused
        registrarChecks(_registrarName)
        onlyOwner
        returns (bool)
    {

        require(isAddressTaken[_registrar] == false, "This address is already registered.");

        Registrars[_registrar] = Registrar({
            isRegisteredRegistrar: true,
            registrarName: _registrarName,
            registrarAddress: _registrar
        });

        registrarNameToAddress[_registrarName] = _registrar;
        registrarNames[ _registrar]= _registrarName;
        isRegisteredRegistrar[_registrar]=true;
        isAddressTaken[_registrar] = true;
        totalRegistrars++;

        emit RegistrarRegistered(_registrar, _registrarName);
        return true;
    }

    function updateRegistrar(address _registrar, string calldata _newRegistrarName)
        external
        WhenNotPaused
        registrarChecks(_newRegistrarName)
        returns (bool)
    {
    
        require(isAddressTaken[_registrar] == true, "Registrar should register first.");
        require(totalRegistrarUpdates[_registrar] + 1 <= MAX_NAME_UPDATES, "Maximum update count reached.");

        Registrar storage registrarObject = Registrars[_registrar];
        string memory oldName = registrarObject.registrarName;

        registrarNameToAddress[oldName] = address(0x0);

        resolveOldRegistrarAddress[_registrar].push(bytes(registrarObject.registrarName));
        registrarNames[ _registrar]=  _newRegistrarName;
        registrarObject.registrarName = _newRegistrarName;
        registrarNameToAddress[_newRegistrarName] = _registrar;
        totalRegistrarUpdates[_registrar]++;

        emit RegistrarUpdated(_registrar, oldName, _newRegistrarName);
        return true;
    }

    function PauseRegistration() external onlyOwner {
        isPaused=true;
    }
    function unPauseRegistration() external onlyOwner {
        isPaused=false;
    }
    // SafleID registration and management functions
    function registerSafleId(
        string calldata _safleId,
        address _registrar,
        address _primaryAddress,
        bytes calldata _signature
    )
        external
        WhenNotPaused
        returns (bool)
    {

        require(isRegisteredRegistrar[msg.sender] == true, "Caller must be a Registrar");
        // Inline modifier logic
        require(!userAddresses[_safleId].exists, "SafleID already exists");
        require(!unavailableSafleIds[_safleId], "SafleID not available");

        // Inline safleIdChecks logic
        require(Registrars[_registrar].registrarAddress != address(0x0), "Invalid Registrar.");
        require(registrarNameToAddress[string(bytes(_safleId))] == address(0x0), "This SafleId is taken by a Registrar.");
        require(resolveAddressFromSafleId[bytes(_safleId)] == address(0x0), "This SafleId is already registered.");
        require(unavailableSafleIds[_safleId] == false, "SafleId is already used once, not available now");
        
        // Inline verifyPrimarySignature logic
        bytes memory data = abi.encodePacked("registerSafleId", _safleId, _primaryAddress);
        require(verifySignature(data, msg.sender, _signature), "Invalid registrar signature");
  

        // Function logic
        UserData storage userData = userAddresses[_safleId];
        userData.primary = _primaryAddress;
        userData.exists = true;

        resolveAddressFromSafleId[bytes(_safleId)] = _primaryAddress;
        resolveUserAddress[_primaryAddress] = _safleId;
        registeredSafleIds.push(_safleId);
        unavailableSafleIds[_safleId] = true;
        totalSafleIdRegistered++;

        return true;
    }


    function addSecondaryAddress(
        string calldata _safleId,
        address _secondaryAddress,
        bytes calldata _primarySignature,
        bytes calldata _secondarySignature
    )
        external
        WhenNotPaused
        safleIdExists(_safleId)

        verifyPrimarySignature(_safleId, userAddresses[_safleId].primary, _primarySignature, "addSecondaryAddress")
        returns (bool)
    {
        require(
            verifySignature(abi.encodePacked("addSecondaryAddress", _safleId, _secondaryAddress), _secondaryAddress, _secondarySignature),
            "Invalid secondary address signature"
        );
        UserData storage userData = userAddresses[_safleId];
        userData.isSecondary[_secondaryAddress] = true;
        userData.secondaries.push(_secondaryAddress);
        emit SecondaryAddressAdded(_safleId, _secondaryAddress);
        return true;
    }

    function removeSecondaryAddress(
        string calldata _safleId,
        address _secondaryAddress,
        bytes calldata _signature
    )
        external
        WhenNotPaused
        safleIdExists(_safleId)
        
        verifyPrimarySignature(_safleId, userAddresses[_safleId].primary, _signature, "removeSecondaryAddress")
        returns (bool)
    {
        UserData storage userData = userAddresses[_safleId];
        userData.isSecondary[_secondaryAddress] = false;

        // Remove from the secondaries array
        for (uint i = 0; i < userData.secondaries.length; i++) {
            if (userData.secondaries[i] == _secondaryAddress) {
                userData.secondaries[i] = userData.secondaries[userData.secondaries.length - 1];
                userData.secondaries.pop();
                break;
            }
        }

        emit SecondaryAddressRemoved(_safleId, _secondaryAddress);
        return true;
    }

    // View functions
    function isPrimaryAddress(string calldata _safleId, address _address)
        external
        view
        returns (bool)
    {
        return userAddresses[_safleId].primary == _address;
    }

    function isSecondaryAddress(string calldata _safleId, address _address)
        external
        view
        returns (bool)
    {
        return userAddresses[_safleId].isSecondary[_address];
    }

    function getPrimaryAddress(string calldata _safleId)
        external
        view
        returns (address)
    {
        return userAddresses[_safleId].primary;
    }

    function getSecondaryAddresses(string calldata _safleId)
        external
        view
        returns (address[] memory)
    {
        return userAddresses[_safleId].secondaries; // Directly return the secondaries array
    }

    function getRegisteredSafleIds() external view returns (string[] memory) {
        return registeredSafleIds;
    }

   
}