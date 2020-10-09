pragma solidity 0.5.16;

interface IWrappedCfx {
    function decimals() external pure returns (uint8);

    function deposit() external payable;

    function depositFor(address holder, bytes calldata recipient)
        external
        payable;

    function withdraw(uint256 amount) external;

    function() external payable;

    event Deposit(address indexed dst, bytes indexed dat, uint256 wad);

    event Withdrawl(address indexed src, uint256 wad);
}
