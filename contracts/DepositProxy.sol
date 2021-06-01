pragma solidity 0.5.16;

import "@openzeppelin/contracts/token/ERC777/IERC777Recipient.sol";
import "./InternalContracts/InternalContractsHandler.sol";
import "./WrappedCfx.sol";

/**
 * DepositProxy is only used to adapt the deposit APIs of WCFX.
 *
 * This is because sponsor whitelist of WCFX is not set and the
 * admin is already set to zero address. As a result, users have
 * to pay gas and storage fees when interact with WCFX.
 *
 * To support sponsorship for WCFX, users could deposit with
 * this proxy contract for gas and storage sponsorship. However,
 * users have to pay gas fee when withdraw CFX from WCFX.
 */
contract DepositProxy is InternalContractsHandler, IERC777Recipient {

    WrappedCfx _wcfx;

    constructor(WrappedCfx wcfx) public {
        _wcfx = wcfx;

        // must register 1820 callback to adapt WCFX
        registry.setInterfaceImplementer(
            address(this),
            keccak256("ERC777TokensRecipient"),
            address(this)
        );
    }

    function () external payable {
        deposit();
    }

    function deposit() public payable {
        _wcfx.deposit.value(msg.value)();
        _wcfx.transfer(msg.sender, msg.value);
    }

    function depositFor(address holder, bytes memory recipient) public payable {
        _wcfx.depositFor.value(msg.value)(holder, recipient);
    }

    // Implement IERC777Recipient interface
    function tokensReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes calldata userData,
        bytes calldata operatorData
    ) external {
        // do nothing, only for callback from WCFX
    }

}