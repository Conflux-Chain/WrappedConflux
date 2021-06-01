pragma solidity 0.5.16;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/introspection/IERC1820Registry.sol";

contract ERC1820Context {
    using Address for address;

    address constant ERC1820_ETH = 0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24;
    address constant ERC1820_CFX = 0x88887eD889e776bCBe2f0f9932EcFaBcDfCd1820;

    bool ethChain;
    bool cfxChain;
    IERC1820Registry registry;

    constructor() public {
        if (ERC1820_ETH.isContract()) {
            ethChain = true;
            registry = IERC1820Registry(ERC1820_ETH);
        } else {
            cfxChain = true;
            registry = IERC1820Registry(ERC1820_CFX);
        }
    }

}