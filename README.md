# Wrapped CFX

## What is WCFX ?

**WCFX is "wrapped CFX"**, an advanced implementation of ERC777.

**FIRST, THERE'S CFX TOKEN**. CFX is the native currency built on the Conflux blockchain, just like ETH on Ethereum.

**SECOND, THERE ARE ALT TOKENS.** When a dApp (decentralized app) is built off of the Conflux Blockchain, it usually implements its own form of Token. 

**FINALLY THE ERC20 STANDARD and ERC777 STANDARD.** ERC20 is a standard developed after the release of ETH that defines how tokens are transferred and how to keep a consistent record of those transfers among tokens in the Ethereum Network. Like ERC20, ERC777 is a standard for [*fungible* tokens](https://docs.openzeppelin.com/contracts/2.x/tokens#different-kinds-of-tokens), and is focused around allowing more complex interactions when trading tokens. But its killer feature is **receive hooks** that enable **accounts and contracts to react to receiving tokens**. Moreover, the ERC777 standard is **backwards compatible with ERC20**. 


## Why you need WCFX ?

**Like ETH, CFX DOESN’T CONFORM TO ERC20/ERC777 STANDARD. Wrapped-CFX allows you to trade directly with a lot of tokens**. The reason you need wCFX is to be able to trade CFX for other ERC20/ERC777 tokens on decentralized platforms built on the Conflux blockchain. Because decentralized paltforms running on Conflux use smart contracts to facilitate trades directly between users, every user needs to have the same standardized format for every token they trade. This ensures tokens don't get lost in translation. 

## More than ERC777

WCFX is a implementation of ERC777. Besides, WCFX has new functions that helps to **"Wrap" CFX** and **"UnWrap" WCFX**.

```solidity
/*** Wrap CFX ***/
//deposit function to Wrap CFX
function deposit() public payable;

//fallback function to accept and wrap CFX 
function () public payable;

//Wrap CFX and deposit directly to contract
function depositFor(address holder, bytes memory recipient) public payable;

/*** UnWrap WCFX ***/
function withdraw(uint256 amount) public;
```

## Implementation of ERC777
1. **approve** with strict **require**

   ```solidity
   function approve(address spender, uint256 value) public returns (bool) {
   		require(!((value != 0) && (_allowances[msg.sender][spender] != 0)));
   		address holder = _msgSender();
   		_approve(holder, spender, value);
   		return true;
   }
   ```

2.  **_burn** to **"UnWrap" WCFX** 

   ```solidity
   function _burn(
   		address operator,
   		address from,
   		uint256 amount,
   		bytes memory data,
   		bytes memory operatorData
   ) internal {
   		require(from != address(0), "ERC777: burn from the zero address");
   
   		_callTokensToSend(
   				operator,
   				from,
   				address(0),
   				amount,
   				data,
   				operatorData
   		);
   
   		// Update state variables
   		_balances[from] = _balances[from].sub(
   				amount,
   				"ERC777: burn amount exceeds balance"
   		);
   		_totalSupply = _totalSupply.sub(amount);
   
   		// withdraw CFX
   		if (data.length == 0) {
   				address payable toAddress = address(uint160(from));
   				toAddress.transfer(amount);
   		} else {
   				address payable toAddress = address(0);
   				assembly {
   						toAddress := mload(add(data, 20))
   				}
   
   				toAddress.transfer(amount);
   		}
   
   		emit Burned(operator, from, amount, data, operatorData);
   		emit Withdrawal(from, amount);
   		emit Transfer(from, address(0), amount);
   }
   ```

   

All methods are detailed in the [contract](/contracts/WrappedCfx.sol).

## How to interact with WCFX

Ways to **"Wrap" CFX** and **"Unwarp" WCFX** 

```solidity
/*** Wrap CFX ***/
//deposit function to Wrap CFX
function deposit() public payable;

//fallback function to accept and wrap CFX 
function () public payable;

//Wrap CFX and deposit directly to contract
function depositFor(address holder, bytes memory recipient) public payable;

/*** UnWrap WCFX ***/
//withdraw CFX directly to msg.sender
function withdraw(uint256 amount) public;

//withdraw CFX to address in parameter data
function burn(uint256 amount, bytes memory data) public;
```
## Deploy address

TBD

