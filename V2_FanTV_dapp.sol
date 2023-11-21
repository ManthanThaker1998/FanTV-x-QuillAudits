// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20CappedUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract V2FanTV_dapp is Initializable, ERC20Upgradeable, ERC20PermitUpgradeable, ERC20VotesUpgradeable, OwnableUpgradeable, ERC20CappedUpgradeable, ERC20BurnableUpgradeable {

    uint256 public totalLiquidSupply;
    address[] public cashierList;
    address public verifier;
    mapping(bytes32 => bool) public hashVerified;


    
    event Credit(address indexed reciever, uint256 amount); //  credit in user account
    event Debit(address indexed sender, uint256 amount ); //debit from user account
    event DepositCashier(address indexed cashier, uint256 amount); // deposit to cashier from smart contract
    //event InitCredit(address indexed initAccount, uint256 amount); // 

    modifier onlyCashier(address targetAddress) {
        require(addressExists(targetAddress), "This address is not cashier");
        _;
    }
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() initializer public {
        __ERC20_init("FanTV IOU Token", "xFanTV");
        __ERC20Burnable_init();
        __ERC20Permit_init("FanTV IOU Token");
        __ERC20Votes_init();
        __ERC20Capped_init(totalSupply());

        __Ownable_init();
    }

    function mint(uint256 amount) public onlyOwner {
        _mint(address(this), amount);
    }

    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20Upgradeable, ERC20VotesUpgradeable)
    {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount)
        internal
        override(ERC20Upgradeable, ERC20VotesUpgradeable, ERC20CappedUpgradeable)
    {
        super._mint(to, amount);
        totalLiquidSupply += amount;
    }

    function burn(address account, uint256 amount) public  onlyOwner{
        _burn(account, amount);
        totalLiquidSupply -= amount;
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20Upgradeable, ERC20VotesUpgradeable)
    {
        super._burn(account, amount);
    }

    function burn(uint256) public pure override {
        revert("You cannot burn");
    }

    function totalSupply() public view virtual override returns (uint256) {
        return 10000000000 * 10 ** decimals();
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function transfer(address, uint256) public pure override returns (bool) {
        revert("Direct transfers are disabled");
    }

    function addAddress(address newAddress) public onlyOwner {
        require(newAddress != address(0), "Invalid address");
        cashierList.push(newAddress);
    }

    function removeAddress(address addressToRemove) public onlyOwner {
        for (uint256 i = 0; i < cashierList.length; i++) {
            if (cashierList[i] == addressToRemove) {
                cashierList[i] = cashierList[cashierList.length - 1];
                cashierList.pop();
                return;
            }
        }
        revert("Address not approved");
    }

    function addressExists(address targetAddress) public view returns (bool) {
        for (uint256 i = 0; i < cashierList.length; i++) {
            if (cashierList[i] == targetAddress) {
                return true;
            }
        }
        return false;
    }

    //transfer tokens from _msgSender() to user
    function credit (address _to, uint256 _amount) public onlyCashier(_msgSender()) {
        
        //1. check balance of _msgSender() is greater than _amount
        require(balanceOf(_msgSender()) >= _amount, "Not enough balance in sender address");

        //2. initiate transfer
        _transfer(_msgSender() , _to, _amount);

        //3. emit Credit event
        emit Credit(_to, _amount);
    }

    //transfer tokens from user to smart contract
    function debit (address _from, uint256 _amount) public {
        
        //check user can redeem coins only for himself
        require(_from == _msgSender() , "Caller of this function is not equal to _from");
        
        //1. check balance of user is greater than _amount
        require(balanceOf(_from) >= _amount, "Not enough balance in user address");

        //2. initiate transfer
        _transfer(_from, address(this), _amount);

        //3. emit Debit event
        emit Debit(_from, _amount);
    }

    //transfer tokens from smart contract to  cashier
    function depositCashier(address _cashier, uint256 _amount) onlyOwner public {
        require(addressExists(_cashier), "This address is not approved cashier");
        require(balanceOf(address(this)) >= _amount, "Balance of smart contract is less than asked amount");

        _transfer(address(this), _cashier, _amount);

        emit DepositCashier(_cashier, _amount);
    }   

    function setVerifier(address _newVerifier) public onlyOwner {
        verifier = _newVerifier;
    }

   function VerifyMessage(bytes32 _hashedMessage, uint8 _v, bytes32 _r, bytes32 _s) public pure returns (address) {
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 prefixedHashMessage = keccak256(abi.encodePacked(prefix, _hashedMessage));
        address signer = ecrecover(prefixedHashMessage, _v, _r, _s);
        return signer;
    }

    //initcredit
    function transferc(
        bytes32 _hashedMessage,
        uint256 _amount,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public  {
        require(_amount > 0, 'Amount should be greater than zero');

        require(hashVerified[_hashedMessage] != true, "Duplicate Hash");
        
        address signer = VerifyMessage(_hashedMessage, v, r, s);
        require(verifier == signer, "Invalid Hash Message");
        hashVerified[_hashedMessage] = true;
        // mint amount to msg.sender
        _mint(msg.sender, _amount);

        emit Credit(msg.sender, _amount);
    }

    //debit
    function transferw (address _from, uint256 _amount) public {
        
        require(_amount > 0, 'Amount should be greater than zero');
        //check user can redeem coins only for himself
        require(_from == _msgSender() , "Caller of this function is not equal to _from");
        
        //1. check balance of user is greater than _amount
        require(balanceOf(_from) >= _amount, "Not enough balance in user address");

        //2. initiate transfer
        _transfer(_from, address(this), _amount);

        //3. emit Debit event
        emit Debit(_from, _amount);
    }
   }


