pragma solidity 0.5.16;

interface IWrappedCfx {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external pure returns (uint8);

    function granularity() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function allowance(address holder, address spender) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function send(address recipient, uint256 amount, bytes calldata data) external;

    function transfer(address recipient, uint256 amount) external returns (bool);

    function transferFrom(address holder, address recipient, uint256 amount) external returns (bool);

    function deposit() external payable;

    function depositFor(address holder, bytes calldata recipient) external payable;

    function burn(uint256 amount, bytes calldata data) external;

    function withdraw(uint256 amount) external;

    function isOperatorFor(address operator, address tokenHolder) external view returns (bool);

    function authorizeOperator(address operator) external;

    function revokeOperator(address operator) external;

    function defaultOperators() external view returns (address[] memory);
    
    function() external payable;

    function operatorSend(
        address sender,
        address recipient,
        uint256 amount,
        bytes calldata data,
        bytes calldata operatorData
    ) external;

    function operatorBurn(
        address account,
        uint256 amount,
        bytes calldata data,
        bytes calldata operatorData
    ) external;

    event Sent(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 amount,
        bytes data,
        bytes operatorData
    );

    event Minted(address indexed operator, address indexed to, uint256 amount, bytes data, bytes operatorData);

    event Burned(address indexed operator, address indexed from, uint256 amount, bytes data, bytes operatorData);

    event AuthorizedOperator(address indexed operator, address indexed tokenHolder);

    event RevokedOperator(address indexed operator, address indexed tokenHolder);

    event Deposit(address indexed dst, bytes indexed dat, uint256 wad);

    event Withdrawl(address indexed src, uint256 wad);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}