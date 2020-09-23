# WrappedConflux

## What is WCFX ?

**WCFX is "wrapped CFX"**, an advanced implementation of ERC777.

**FIRST, THERE'S CFX TOKEN**. CFX is the native currency built on the Conflux blockchain, just like ETH on Ethereum.

**SECOND, THERE ARE ALT TOKENS.** When a dApp (decentralized app) is built off of the Conflux Blockchain it usually implements its own form of Token. Think CRCL Token in Boomflow.

**FINALLY THE ERC20 STANDARD and ERC777 STANDARD.** ERC20 is a standard developed after the release of ETH that defines how tokens are transferred and how to keep a consistent record of those transfers among tokens in the Ethereum Network. Like ERC20, ERC777 is a standard for [*fungible* tokens](https://docs.openzeppelin.com/contracts/2.x/tokens#different-kinds-of-tokens), and is focused around allowing more complex interactions when trading tokens. But its killer feature is **receive hooks** that enable **accounts and contracts to react to receiving tokens**. Moreover, the ERC777 standard is **backwards compatible with ERC20**. 


## Why you need WCFX ?

**Like ETH, CFX DOESN’T CONFORM TO ERC20/ERC777 STANDARD. Wrapped-CFX allows you to trade directly with a lot of tokens**. The reason you need wCFX is to be able to trade CFX for other ERC20/ERC777 tokens on decentralized platforms built on the Conflux blockchain. Because decentralized paltforms running on Conflux use smart contracts to facilitate trades directly between users, every user needs to have the same standardized format for every token they trade. This ensures tokens don't get lost in translation. 

## Contract Methods

WCFX is a implementation of ERC-777. Besides, WCFX has new functions that helps to **"Wrap" CFX** and **"UnWrap" WCFX**.

```solidity
function deposit() public payable;//Wrap CFX
function depositFor(address holder, bytes memory recipient) public payable;//Wrap CFX and deposit directly to contract
function withdraw(uint256 amount) public;//UnWrap WCFX
```

All methods are detailed in the [contract interface](/contracts/IWrappedCfx.sol).

## Deploy address

TBD

