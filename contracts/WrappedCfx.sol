pragma solidity 0.5.11;

import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777Recipient.sol";
import "@openzeppelin/contracts/token/ERC777/IERC777Sender.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/introspection/IERC1820Registry.sol";
import "@openzeppelin/contracts/lifecycle/Pausable.sol";

contract WrappedCfx is Context, IERC777, IERC20, Pausable {
    using SafeMath for uint256;
    using Address for address;

    IERC1820Registry private constant ERC1820_REGISTRY = IERC1820Registry(
        //address(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24)
        address(0x866aCA87FF33a0ae05D2164B3D999A804F583222)
    );

    mapping(address => uint256) private _balances;

    uint256 private _totalSupply;

    string private constant _name = "Wrapped Conflux";
    string private constant _symbol = "WCFX";

    // keccak256("ERC777TokensSender")
    bytes32
        private constant TOKENS_SENDER_INTERFACE_HASH = 0x29ddb589b1fb5fc7cf394961c1adf5f8c6454761adf795e67fe149f658abe895;

    // keccak256("ERC777TokensRecipient")
    bytes32
        private constant TOKENS_RECIPIENT_INTERFACE_HASH = 0xb281fc8c12954d22544db45de3159a39272895b169a852b314f9cc762e44c53b;

    event Deposit(address indexed dst, bytes indexed dat, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    // This isn't ever read from - it's only used to respond to the defaultOperators query.
    address[] private _defaultOperatorsArray;

    // Immutable, but accounts may revoke them (tracked in __revokedDefaultOperators).
    mapping(address => bool) private _defaultOperators;

    // For each account, a mapping of its operators and revoked default operators.
    mapping(address => mapping(address => bool)) private _operators;
    mapping(address => mapping(address => bool))
        private _revokedDefaultOperators;

    // ERC20-allowances
    mapping(address => mapping(address => uint256)) private _allowances;

    // data migration
    address public _creator;
    address[] public _account_list;
    mapping(address => bool) _account_set;
    bool public in_migration;

    /**
     * @dev `defaultOperators` may be an empty array.
     */
    constructor(address[] memory defaultOperators) public {
        _defaultOperatorsArray = defaultOperators;
        for (uint256 i = 0; i < _defaultOperatorsArray.length; i++) {
            _defaultOperators[_defaultOperatorsArray[i]] = true;
            addAccount(_defaultOperatorsArray[i]);
        }

        // register interfaces
        ERC1820_REGISTRY.setInterfaceImplementer(
            address(this),
            keccak256("ERC777Token"),
            address(this)
        );
        ERC1820_REGISTRY.setInterfaceImplementer(
            address(this),
            keccak256("ERC20Token"),
            address(this)
        );

        _creator = _msgSender();
        in_migration = true;
    }

    /**
     * @dev See {IERC777-name}.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC777-symbol}.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {ERC20Detailed-decimals}.
     *
     * Always returns 18, as per the
     * [ERC777 EIP](https://eips.ethereum.org/EIPS/eip-777#backward-compatibility).
     */
    function decimals() public pure returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC777-granularity}.
     *
     * This implementation always returns `1`.
     */
    function granularity() public view returns (uint256) {
        return 1;
    }

    /**
     * @dev See {IERC777-totalSupply}.
     */
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev Returns the amount of tokens owned by an account (`tokenHolder`).
     */
    function balanceOf(address tokenHolder) public view returns (uint256) {
        return _balances[tokenHolder];
    }

    /**
     * @dev See {IERC777-send}.
     *
     * Also emits a {IERC20-Transfer} event for ERC20 compatibility.
     */
    function send(
        address recipient,
        uint256 amount,
        bytes memory data
    ) public whenNotPaused {
        _send(_msgSender(), _msgSender(), recipient, amount, data, "", true);
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Unlike `send`, `recipient` is _not_ required to implement the {IERC777Recipient}
     * interface if it is a contract.
     *
     * Also emits a {Sent} event.
     */
    function transfer(address recipient, uint256 amount)
        public
        whenNotPaused
        returns (bool)
    {
        require(
            recipient != address(0),
            "ERC777: transfer to the zero address"
        );

        address from = _msgSender();

        _callTokensToSend(from, from, recipient, amount, "", "");

        _move(from, from, recipient, amount, "", "");

        _callTokensReceived(from, from, recipient, amount, "", "", false);

        return true;
    }

    function withdraw(uint256 amount) public {
        burn(amount, "");
    }

    /**
     * @dev See {IERC777-burn}.
     *
     * Also emits a {IERC20-Transfer} event for ERC20 compatibility.
     */
    function burn(uint256 amount, bytes memory data) public whenNotPaused {
        _burn(_msgSender(), _msgSender(), amount, data, "");
    }

    /**
     * @dev See {IERC777-isOperatorFor}.
     */
    function isOperatorFor(address operator, address tokenHolder)
        public
        view
        returns (bool)
    {
        return
            operator == tokenHolder ||
            (_defaultOperators[operator] &&
                !_revokedDefaultOperators[tokenHolder][operator]) ||
            _operators[tokenHolder][operator];
    }

    /**
     * @dev See {IERC777-authorizeOperator}.
     */
    function authorizeOperator(address operator) public whenNotPaused {
        require(
            _msgSender() != operator,
            "ERC777: authorizing self as operator"
        );

        if (_defaultOperators[operator]) {
            delete _revokedDefaultOperators[_msgSender()][operator];
        } else {
            _operators[_msgSender()][operator] = true;
        }

        emit AuthorizedOperator(operator, _msgSender());

        addAccount(_msgSender());
        addAccount(operator);
    }

    /**
     * @dev See {IERC777-revokeOperator}.
     */
    function revokeOperator(address operator) public whenNotPaused {
        require(operator != _msgSender(), "ERC777: revoking self as operator");

        if (_defaultOperators[operator]) {
            _revokedDefaultOperators[_msgSender()][operator] = true;
        } else {
            delete _operators[_msgSender()][operator];
        }

        emit RevokedOperator(operator, _msgSender());

        addAccount(_msgSender());
        addAccount(operator);
    }

    /**
     * @dev See {IERC777-defaultOperators}.
     */
    function defaultOperators() public view returns (address[] memory) {
        return _defaultOperatorsArray;
    }

    /**
     * @dev See {IERC777-operatorSend}.
     *
     * Emits {Sent} and {IERC20-Transfer} events.
     */
    function operatorSend(
        address sender,
        address recipient,
        uint256 amount,
        bytes memory data,
        bytes memory operatorData
    ) public whenNotPaused {
        require(
            isOperatorFor(_msgSender(), sender),
            "ERC777: caller is not an operator for holder"
        );
        _send(
            _msgSender(),
            sender,
            recipient,
            amount,
            data,
            operatorData,
            true
        );
    }

    /**
     * @dev See {IERC777-operatorBurn}.
     *
     * Emits {Burned} and {IERC20-Transfer} events.
     */
    function operatorBurn(
        address account,
        uint256 amount,
        bytes memory data,
        bytes memory operatorData
    ) public whenNotPaused {
        require(
            isOperatorFor(_msgSender(), account),
            "ERC777: caller is not an operator for holder"
        );
        _burn(_msgSender(), account, amount, data, operatorData);
    }

    /**
     * @dev See {IERC20-allowance}.
     *
     * Note that operator and allowance concepts are orthogonal: operators may
     * not have allowance, and accounts with allowance may not be operators
     * themselves.
     */
    function allowance(address holder, address spender)
        public
        view
        returns (uint256)
    {
        return _allowances[holder][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Note that accounts cannot have allowance issued by their operators.
     */
    function approve(address spender, uint256 value)
        public
        whenNotPaused
        returns (bool)
    {
        require(!((value != 0) && (_allowances[msg.sender][spender] != 0)));
        address holder = _msgSender();
        _approve(holder, spender, value);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Note that operator and allowance concepts are orthogonal: operators cannot
     * call `transferFrom` (unless they have allowance), and accounts with
     * allowance cannot call `operatorSend` (unless they are operators).
     *
     * Emits {Sent}, {IERC20-Transfer} and {IERC20-Approval} events.
     */
    function transferFrom(
        address holder,
        address recipient,
        uint256 amount
    ) public whenNotPaused returns (bool) {
        require(
            recipient != address(0),
            "ERC777: transfer to the zero address"
        );
        require(holder != address(0), "ERC777: transfer from the zero address");

        address spender = _msgSender();

        _callTokensToSend(spender, holder, recipient, amount, "", "");

        _move(spender, holder, recipient, amount, "", "");
        _approve(
            holder,
            spender,
            _allowances[holder][spender].sub(
                amount,
                "ERC777: transfer amount exceeds allowance"
            )
        );

        _callTokensReceived(spender, holder, recipient, amount, "", "", false);

        return true;
    }

    function deposit() public payable {
        _mint(msg.sender, msg.sender, msg.value, "", "");
        emit Deposit(msg.sender, "", msg.value);
    }

    function() external payable {
        deposit();
    }

    // Deposit WCFX to `holder` address and pass `recipient` as UserData; this is primarily
    // used for depositing CFX directly to DeFi contracts in one transaction
    function depositFor(address holder, bytes memory recipient) public payable {
        _mint(msg.sender, holder, msg.value, recipient, "");
        emit Deposit(holder, recipient, msg.value);
    }

    /**
     * @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * If a send hook is registered for `account`, the corresponding function
     * will be called with `operator`, `data` and `operatorData`.
     *
     * See {IERC777Sender} and {IERC777Recipient}.
     *
     * Emits {Minted} and {IERC20-Transfer} events.
     *
     * Requirements
     *
     * - `account` cannot be the zero address.
     * - if `account` is a contract, it must implement the {IERC777Recipient}
     * interface.
     */
    function _mint(
        address operator,
        address account,
        uint256 amount,
        bytes memory userData,
        bytes memory operatorData
    ) internal {
        require(account != address(0), "ERC777: mint to the zero address");

        // Update state variables
        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);

        _callTokensReceived(
            operator,
            address(0),
            account,
            amount,
            userData,
            operatorData,
            true
        );

        emit Minted(operator, account, amount, userData, operatorData);
        emit Transfer(address(0), account, amount);

        addAccount(account);
    }

    /**
     * @dev Send tokens
     * @param operator address operator requesting the transfer
     * @param from address token holder address
     * @param to address recipient address
     * @param amount uint256 amount of tokens to transfer
     * @param userData bytes extra information provided by the token holder (if any)
     * @param operatorData bytes extra information provided by the operator (if any)
     * @param requireReceptionAck if true, contract recipients are required to implement ERC777TokensRecipient
     */
    function _send(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes memory userData,
        bytes memory operatorData,
        bool requireReceptionAck
    ) private {
        require(from != address(0), "ERC777: send from the zero address");
        require(to != address(0), "ERC777: send to the zero address");

        _callTokensToSend(operator, from, to, amount, userData, operatorData);

        _move(operator, from, to, amount, userData, operatorData);

        _callTokensReceived(
            operator,
            from,
            to,
            amount,
            userData,
            operatorData,
            requireReceptionAck
        );

        addAccount(to);
    }

    /**
     * @dev Burn tokens
     * @param operator address operator requesting the operation
     * @param from address token holder address
     * @param amount uint256 amount of tokens to burn
     * @param data bytes extra information provided by the token holder
     * @param operatorData bytes extra information provided by the operator (if any)
     */
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
        address payable toAddress = address(uint160(from));
        toAddress.transfer(amount);

        emit Burned(operator, from, amount, data, operatorData);
        emit Withdrawal(from, amount);
        emit Transfer(from, address(0), amount);
    }

    function _move(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes memory userData,
        bytes memory operatorData
    ) private {
        _balances[from] = _balances[from].sub(
            amount,
            "ERC777: transfer amount exceeds balance"
        );
        _balances[to] = _balances[to].add(amount);

        emit Sent(operator, from, to, amount, userData, operatorData);
        emit Transfer(from, to, amount);

        addAccount(to);
    }

    function _approve(
        address holder,
        address spender,
        uint256 value
    ) private {
        // TODO: restore this require statement if this function becomes internal, or is called at a new callsite. It is
        // currently unnecessary.
        //require(holder != address(0), "ERC777: approve from the zero address");
        require(spender != address(0), "ERC777: approve to the zero address");

        _allowances[holder][spender] = value;
        emit Approval(holder, spender, value);

        addAccount(holder);
        addAccount(spender);
    }

    /**
     * @dev Call from.tokensToSend() if the interface is registered
     * @param operator address operator requesting the transfer
     * @param from address token holder address
     * @param to address recipient address
     * @param amount uint256 amount of tokens to transfer
     * @param userData bytes extra information provided by the token holder (if any)
     * @param operatorData bytes extra information provided by the operator (if any)
     */
    function _callTokensToSend(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes memory userData,
        bytes memory operatorData
    ) private {
        address implementer = ERC1820_REGISTRY.getInterfaceImplementer(
            from,
            TOKENS_SENDER_INTERFACE_HASH
        );
        if (implementer != address(0)) {
            IERC777Sender(implementer).tokensToSend(
                operator,
                from,
                to,
                amount,
                userData,
                operatorData
            );
        }
    }

    /**
     * @dev Call to.tokensReceived() if the interface is registered. Reverts if the recipient is a contract but
     * tokensReceived() was not registered for the recipient
     * @param operator address operator requesting the transfer
     * @param from address token holder address
     * @param to address recipient address
     * @param amount uint256 amount of tokens to transfer
     * @param userData bytes extra information provided by the token holder (if any)
     * @param operatorData bytes extra information provided by the operator (if any)
     * @param requireReceptionAck if true, contract recipients are required to implement ERC777TokensRecipient
     */
    function _callTokensReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes memory userData,
        bytes memory operatorData,
        bool requireReceptionAck
    ) private {
        address implementer = ERC1820_REGISTRY.getInterfaceImplementer(
            to,
            TOKENS_RECIPIENT_INTERFACE_HASH
        );
        if (implementer != address(0)) {
            IERC777Recipient(implementer).tokensReceived(
                operator,
                from,
                to,
                amount,
                userData,
                operatorData
            );
        } else if (requireReceptionAck) {
            require(
                !to.isContract(),
                "ERC777: token recipient contract has no implementer for ERC777TokensRecipient"
            );
        }
    }

    /*===== Data Migration =====*/
    modifier whenMigration() {
        require(in_migration, "migration finished");
        require(paused(), "token not paused in migration");
        _;
    }

    modifier onlyCreator() {
        require(_msgSender() == _creator, "sender is not creator");
        _;
    }

    function finishMigration() public onlyCreator {
        in_migration = false;
    }

    function addAccount(address account) public {
        if (!_account_set[account]) {
            _account_set[account] = true;
            _account_list.push(account);
        }
    }

    function accountCount() public view returns (uint256) {
        return _account_list.length;
    }

    function setTotalSupply(uint256 newTotalSupply)
        public
        onlyCreator
        whenMigration
    {
        _totalSupply = newTotalSupply;
    }

    function setBalance(address account, uint256 balance)
        public
        onlyCreator
        whenMigration
    {
        _balances[account] = balance;
    }

    function setAllowance(
        address holder,
        address spender,
        uint256 amount
    ) public onlyCreator whenMigration {
        _approve(holder, spender, amount);
    }

    function setOpeartor(address tokenHolder, address operator)
        public
        onlyCreator
        whenMigration
    {
        require(
            tokenHolder != operator,
            "ERC777: authorizing self as operator"
        );

        if (_defaultOperators[operator]) {
            delete _revokedDefaultOperators[tokenHolder][operator];
        } else {
            _operators[tokenHolder][operator] = true;
        }
    }

    function setRevokedDefaultOperator(address tokenHolder, address operator)
        public
        onlyCreator
        whenMigration
    {
        require(tokenHolder != operator, "ERC777: revoking self as operator");

        if (_defaultOperators[operator]) {
            _revokedDefaultOperators[tokenHolder][operator] = true;
        }
    }
}
