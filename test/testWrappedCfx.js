// note here we use ethereum truffle for testing, so the ERC1820 in contract should be modified to
// ethereum version. The address format is also ethereum version which is different from conflux,
// whose user address starts with 1 and contract address starts with 8.
const {
  BN,
  expectEvent,
  expectRevert,
  singletons,
} = require('@openzeppelin/test-helpers');

const assert = require('assert');

const WrappedConflux = artifacts.require('WrappedCfx');

contract('WrappedConflux', (admins) => {
  let wrapped_conflux;
  let admin, toHex, w3;

  before(async function () {
    admin = admins[0];
    w3 = web3;
    toHex = w3.utils.toHex;
    await singletons.ERC1820Registry(admin);
    wrapped_conflux = await WrappedConflux.new([], {from: admin});
    assert.strictEqual(toHex(await wrapped_conflux.totalSupply.call()), toHex(0));
  });
  it('deposit', async () => {
    let before_deposit, after_deposit;
    before_deposit = await w3.eth.getBalance(admin);
    await wrapped_conflux.deposit({from: admin, value: 1e18});
    after_deposit = await w3.eth.getBalance(admin);
    console.log(before_deposit - after_deposit);
    assert.strictEqual(toHex(await wrapped_conflux.balanceOf.call(admin)), toHex(1e18));
    assert.strictEqual(toHex(await wrapped_conflux.totalSupply.call()), toHex(1e18));
    assert.strictEqual(toHex(await w3.eth.getBalance(wrapped_conflux.address)), toHex(1e18));

    before_deposit = await w3.eth.getBalance(admin);
    await wrapped_conflux.sendTransaction({from: admin, value: 1e18});
    after_deposit = await w3.eth.getBalance(admin);
    console.log(before_deposit - after_deposit);
    assert.strictEqual(toHex(await wrapped_conflux.balanceOf.call(admin)), toHex(2e18));
    assert.strictEqual(toHex(await wrapped_conflux.totalSupply.call()), toHex(2e18));
    assert.strictEqual(toHex(await w3.eth.getBalance(wrapped_conflux.address)), toHex(2e18));
  });
  it('withdraw', async () => {
    let before_withdraw, after_withdraw;
    before_withdraw = await w3.eth.getBalance(admin);
    await wrapped_conflux.burn(toHex(5e17), "0x", {from: admin});
    after_withdraw = await w3.eth.getBalance(admin);
    console.log(after_withdraw - before_withdraw);
    assert.strictEqual(toHex(await wrapped_conflux.balanceOf.call(admin)), toHex(1e18 + 5e17));
    assert.strictEqual(toHex(await wrapped_conflux.totalSupply.call()), toHex(1e18 + 5e17));
    assert.strictEqual(toHex(await w3.eth.getBalance(wrapped_conflux.address)), toHex(1e18 + 5e17));

    before_withdraw = await w3.eth.getBalance(admin);
    await wrapped_conflux.withdraw(toHex(1e18 + 5e17), {from: admin});
    after_withdraw = await w3.eth.getBalance(admin);
    console.log(after_withdraw - before_withdraw);
    assert.strictEqual(toHex(await wrapped_conflux.balanceOf.call(admin)), toHex(0));
    assert.strictEqual(toHex(await wrapped_conflux.totalSupply.call()), toHex(0));
    assert.strictEqual(toHex(await w3.eth.getBalance(wrapped_conflux.address)), toHex(0));
  });
});
