pragma solidity 0.5.16;

import "./AdminControl.sol";
import "./SponsorWhitelistControl.sol";
import "./ERC1820Context.sol";

contract InternalContractsHandler is ERC1820Context {

    constructor() public {
        if (!cfxChain) {
            return;
        }

        // register all users as sponsees
        address[] memory users = new address[](1);
        users[0] = address(0);
        SponsorWhitelistControl(0x0888000000000000000000000000000000000001).addPrivilege(users);

        // remove contract admin
        AdminControl(0x0888000000000000000000000000000000000000).setAdmin(address(this), address(0));
    }
}
