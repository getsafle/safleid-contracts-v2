pragma solidity ^0.8.13;

import "./checkingContract.sol";

contract RegistrarStorage is checkingContract {
    
    struct ChainData {
        address primary;
        mapping(address => bool) isSecondary;
    }

    struct registrar {
        bool isRegisteredRegistrar;
        string registrarName;
        address registarAddress;
    }

    struct otherCoin {
        string coinName;
        string aliasName;
        bool isIndexMapped;
    }
    
    struct UserChainData {
        mapping(uint256 => ChainData) chains;
        string[] registeredChains;
        bool exists;
    }

    uint256 public registrarFees;
    uint256 public safleIdFees;
    address public contractOwner;
    address payable public walletAddress;

    bool public safleIdRegStatus;

   

    // uint8 constant MAX_NAME_UPDATES = 2;
    uint256 public totalRegistrars;
    uint256 public totalSafleIdRegistered;
    
    // Registrar-related mappings
    mapping(address => bool) public isRegisteredRegistrar;
    mapping(address => string) public registrarNames;
    mapping(string => address) public registrarNameToAddress;
    mapping(address => uint8) public totalRegistrarUpdates;
    mapping(address => uint8) public totalRegistrarNameUpdates;
    mapping( address => uint8 ) public totalSafleIDCount;
    mapping( address => bytes[] ) public resolveOldRegistrarAddress;
    mapping( address => registrar ) public Registrars;
    // User and chain mappings
    mapping(string => UserChainData) private userAddresses;
    mapping(string => bool) public unavailableSafleIds;
    string[] public registeredSafleIds;
    
    // Dynamic array of supported chain IDs
    uint256[] public supportedChainIds;

    // Mappings to manage the SafleID functionalities
    mapping( bytes => address ) resolveAddressFromSafleId;
    mapping( address => bool ) public isAddressTaken;
    mapping( address => string ) public resolveUserAddress;
 
    mapping( address => bytes[] ) public resolveOldSafleIdFromAddress;
    mapping( bytes => address )  resolveOldSafleID;

    // Events
    event PrimaryAddressUpdated(string indexed safleId, string chain, address newPrimary);
    event SecondaryAddressAdded(string indexed safleId, string chain, address secondary);
    event ChainRegistered(string indexed safleId, string chain);
    event SecondaryAddressRemoved(string indexed safleId, string chain, address secondary);
    event RegistrarRegistered(address indexed registrar, string registrarName);
    event RegistrarUpdated(address indexed registrar, string oldName, string newName);

    string constant PREFIX = "\x19Ethereum Signed Message:\n32";
    
    // Existing modifiers from first contract
    modifier onlyOwner() {
            require(msg.sender == contractOwner, "Only owner can call");
            _;
        }
    
    modifier safleIdExists(string memory _safleId) {
            require(userAddresses[_safleId].exists, "SafleID does not exist");
            _;
        }

    modifier safleIdDoesNotExist(string memory _safleId) {
            require(!userAddresses[_safleId].exists, "SafleID already exists");
            require(!unavailableSafleIds[_safleId], "SafleID not available");
            _;
        }

    modifier chainExists(string memory _safleId, string memory  _chainID) {
            require(userAddresses[_safleId].chains[ _chainID].primary != address(0), "Chain not registered");
            _;
        }

    modifier chainDoesNotExist(string memory _safleId, string memory  _chainID) {
            require(userAddresses[_safleId].chains[ _chainID].primary == address(0), "Chain already registered");
            _;
        }



    modifier registrarChecks(string memory _registrarName) {
            bytes memory regNameBytes = bytes(_registrarName);
            require(registrarNameToAddress[regNameBytes] == address(0x0), "Registrar name is already taken.");
            require(resolveAddressFromSafleId[regNameBytes] == address(0x0), "This Registrar name is already registered as a SafleID.");
            _;
        }

        //Modifier to ensure that necessary conditions are satified before registering or updating SafleID
    modifier safleIdChecks (string memory _safleId, address _registrar) {

            bytes memory idBytes = bytes(_safleId);

            require(Registrars[_registrar].registarAddress != address(0x0), "Invalid Registrar.");
            require(registrarNameToAddress[idBytes] == address(0x0), "This SafleId is taken by a Registrar.");
            require(resolveAddressFromSafleId[idBytes] == address(0x0), "This SafleId is already registered.");
            require(unavailableSafleIds[_safleId] == false, "SafleId is already used once, not available now");
            _;

        }

     // Modifier to check if the chainID is supported
    modifier ChainisSupported(uint256 chainID) {
            bool isSupported = false;
            for (uint256 i = 0; i < supportedChainIds.length; i++) {
                if (supportedChainIds[i] == chainID) {
                    isSupported = true;
                    break;
                }
            }
            require(isSupported, "ChainID is not supported");
            _;
        }

   
    // Signature verification modifiers
    modifier verifyRegistrarOrUserSignature(
            string memory _safleId,
        
            address _primaryAddress,
            bytes memory _signature,
            string memory _operation
        ) {
            bytes memory data = abi.encodePacked(_operation, _safleId, _primaryAddress);
            if (isRegisteredRegistrar[msg.sender]) {
                require(verifySignature(data, msg.sender, _signature), "Invalid registrar signature");
            } else {

                require(msg.sender == _primaryAddress, "Caller must be primary address");
                require(verifySignature(data, _primaryAddress, _signature), "Invalid user signature");
            }
            _;
        }

    // Constructor
    constructor(address _mainContractAddress) public {
            contractOwner = msg.sender;
      

            // Initial supported chains
            supportedChainIds.push(1);     // Ethereum
            supportedChainIds.push(137);   // Polygon
            supportedChainIds.push(8453);  // Base
        }

    // Existing signature verification functions from first contract
    function getMessageHash(bytes memory _data) 
            public 
            pure 
            returns (bytes32) 
        {
            return keccak256(_data);
        }

    function getEthSignedMessageHash(bytes32 _messageHash)
            public
            pure
            returns (bytes32)
        {
            return keccak256(abi.encodePacked(PREFIX, _messageHash));
        }

    function recoverSigner(bytes32 _ethSignedMessageHash, bytes memory _signature)
            public
            pure
            returns (address)
        {
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
        )
            public
            pure
            returns (bool)
        {
            bytes32 messageHash = getMessageHash(_data);
            bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
            address signer = recoverSigner(ethSignedMessageHash, _signature);
            return signer == _expectedSigner;
        }
    // Owner functions for chain management
    function addSupportedChain(uint256 _chainId) 
        external 
        onlyOwner 
        {
            // Ensure chain ID is not already supported
            for (uint i = 0; i < supportedChainIds.length; i++) {
                require(supportedChainIds[i] != _chainId, "Chain ID already supported");
            }
            
            supportedChainIds.push(_chainId);
        }

    function removeSupportedChain(uint256 _chainId) 
        external 
        onlyOwner 
        {
            for (uint i = 0; i < supportedChainIds.length; i++) {
                if (supportedChainIds[i] == _chainId) {
                    // Replace with last element and then pop
                    supportedChainIds[i] = supportedChainIds[supportedChainIds.length - 1];
                    supportedChainIds.pop();
                    return;
                }
            }
            revert("Chain ID not found");
        }
    // Existing functions from first contract
    function registerSafleId(
            string calldata _safleId,
            address  _registrar,
            address _primaryAddress,
            bytes calldata _signature
        ) 
            external 
            safleIdDoesNotExist(_safleId)
            safleIdChecks(_safleId, _registrar)
            verifyRegistrarOrUserSignature(_safleId, _primaryAddress, _signature, "registerSafleId")
            returns(bool) 
        {
            bytes memory idBytes = bytes(_safleId);
            UserChainData storage userData = userAddresses[_safleId];
            userData.exists = true;
                // Iterate through supported chains and set primary address
            for (uint i = 0; i < supportedChainIds.length; i++) {
                uint256 currentChainId = supportedChainIds[i];
                
                // Set the public address as primary for all supported chains
                userData.chains[currentChainId].primary = _primaryAddress;
                
                // Add to registered chain IDs
                userData.registeredChainIds.push(currentChainId);
                
                // Emit chain registration and primary address update events
                emit ChainRegistered(_safleId, currentChainId);
                emit PrimaryAddressUpdated(_safleId, currentChainId,_primaryAddress);
            }

            resolveAddressFromSafleId[idBytes] = _primaryAddress;
            resolveUserAddress[_primaryAddress] = _safleId;
            registeredSafleIds.push(_safleId);
            unavailableSafleIds[_safleId] = true;
            totalSafleIdRegistered++;
            
    
            return true;
        }
    function addChain(
            string calldata _safleId,
            uint256 calldata _chainID,
            uint256 calldata _newchainID,
            address _primaryAddress,
            bytes calldata _signature
        )
            external
            ChainisSupported(_newchainID)
            safleIdExists(_safleId)
            chainDoesNotExist(_safleId,  _chainID)
        
            returns(bool)
        {
            UserChainData storage userData = userAddresses[_safleId];
            userData.registeredChains.push( _chainID);
            userData.chains[ _chainID].primary = _primaryAddress;
            
            emit ChainRegistered(_safleId,  _chainID);
            emit PrimaryAddressUpdated(_safleId,  _chainID, _primaryAddress);
            return true;
        }


    //How would be update resolveUseraddress which is     mapping( address => string ) public resolveUserAddress; on updation of primary address
    function updatePrimaryAddress(
            string calldata _safleId,
            uint256 calldata _chainID,
            address _newPrimary,
            bytes calldata _signature
        )
            external
            safleIdExists(_safleId)
            chainExists(_safleId,  _chainID)
        //CheckIfItIsAlreadyaprimary    
        
            returns(bool)
        {
            ChainData storage chainData = userAddresses[_safleId].chains[ _chainID];
            chainData.primary = _newPrimary;
            emit PrimaryAddressUpdated(_safleId,  _chainID, _newPrimary);
            return true;
        }
        
    function addSecondaryAddress(
            string calldata _safleId,
            uint256 calldata _chainID,
            address _secondaryAddress,
            bytes calldata _signature
        )
            external
            safleIdExists(_safleId)
            chainExists(_safleId,  _chainID)
        //CheckIfItIsAlreadyasecondary
        
        
            returns(bool)
        {
            ChainData storage chainData = userAddresses[_safleId].chains[ _chainID];
            chainData.isSecondary[_secondaryAddress] = true;
            emit SecondaryAddressAdded(_safleId,  _chainID, _secondaryAddress);
            return true;
        }
        
    function removeSecondaryAddress(
            string calldata _safleId,
            uint256 calldata _chainID,
            address _secondaryAddress,
            bytes calldata _signature
        )
            external
            safleIdExists(_safleId)
            chainExists(_safleId,  _chainID)
        //CheckIfSecondaryNotPresent
        
            returns(bool)
        {
            ChainData storage chainData = userAddresses[_safleId].chains[ _chainID];
            chainData.isSecondary[_secondaryAddress] = false;
            emit SecondaryAddressRemoved(_safleId,  _chainID, _secondaryAddress);
            return true;
        }


    function registerRegistrar(address _registrar, string calldata _registrarName)
     external
     registrarChecks(_registrarName)
     onlyOwner
     returns(bool)  {

        bytes memory regNameBytes = bytes(_registrarName);

        require(isAddressTaken[_registrar] == false, "This address is already registered.");

        Registrars[_registrar].isRegisteredRegistrar = true;
        Registrars[_registrar].registrarName = _registrarName;
        Registrars[_registrar].registarAddress = _registrar;

        registrarNameToAddress[regNameBytes] = _registrar;
        isAddressTaken[_registrar] = true;
        totalRegistrars++;

        return true;
     }

 
    function updateRegistrar(address _registrar, string calldata _newRegistrarName)
      external
      registrarChecks(_newRegistrarName)

      returns (bool) {

        bytes memory newNameBytes = bytes(_newRegistrarName);

        require(isAddressTaken[_registrar] == true, "Registrar should register first.");
        require(totalRegistrarUpdates[_registrar]+1 <= MAX_NAME_UPDATES, "Maximum update count reached.");

        registrar memory registrarObject = Registrars[_registrar];
        string memory oldName = registrarObject.registrarName;
        bytes memory oldNameBytes = bytes(oldName);
        registrarNameToAddress[oldNameBytes] = address(0x0);

        resolveOldRegistrarAddress[_registrar].push(bytes(Registrars[_registrar].registrarName));
        
        Registrars[_registrar].registrarName = _newRegistrarName;
        Registrars[_registrar].registarAddress = _registrar;

        registrarNameToAddress[newNameBytes] = _registrar;
        totalRegistrarUpdates[_registrar]++;
        return true;

      }

    
    
    function resolveSafleId(string calldata _safleId,uint256 calldata _chainID) public {
        return userAddresses[_safleId].chains[_chainID].primary;
        }


    function setSafleIdFees(uint256 _amount) public onlyOwner
        {
            require(_amount >= 0, "Please set a fees for SafleID registration.");
            safleIdFees = _amount;

        }   
    function setRegistrarFees(uint256 _amount) public onlyOwner
        {
            require(_amount >= 0, "Please set a fees for Registrar registration.");
            registrarFees = _amount;

        }
    function updateWalletAddress(address payable _walletAddress) onlyOwner
        public

        {
            require(!isContract(_walletAddress));
            walletAddress = _walletAddress;

        }
    function toggleRegistrationStatus () external onlyOwner returns (bool){

        if(safleIdRegStatus == false){
            safleIdRegStatus = true;
        }else{
            safleIdRegStatus = false;
        }
        return true;

        }
    
   
   
    
    function isPrimaryAddress(
        string calldata _safleId,
        uint256 calldata _chainID,
        address _address
        )
            external
            view
            returns(bool)
        {
            return userAddresses[_safleId].chains[ _chainID].primary == _address;
        }
        
    function isSecondaryAddress(
            string calldata _safleId,
            uint256 calldata _chainID,
            address _address
        )
            external
            view
            returns(bool)
        {
            return userAddresses[_safleId].chains[ _chainID].isSecondary[_address];
        }
    
    
    function getPrimaryAddress(
        string calldata _safleId,
        uint256 calldata _chainID
         )
            external
            view
            returns(address)
        {
            return userAddresses[_safleId].chains[_chainID].primary;
        }
    function getSecondaryAddress(
        string calldata _safleId,
        uint256 calldata _chainID
         )
            external
            view
            returns(address)
        {
           //How would we do this? since isSecondary is a mapping(address => bool) isSecondary;
        }

    
    function getRegisteredChains(string calldata _safleId)
        external
        view
        returns(string[] memory)
        {
            return userAddresses[_safleId].registeredChains;
        }  
	}