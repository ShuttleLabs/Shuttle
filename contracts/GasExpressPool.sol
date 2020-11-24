pragma solidity ^0.6.6;
pragma experimental ABIEncoderV2;

import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import '@uniswap/v2-periphery/contracts/interfaces/IERC20.sol';
import '@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol';
import "@openzeppelin/contracts/access/Ownable.sol";

library SafeMath2 {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

contract GasExpressPool is Ownable {
    using SafeMath2 for uint256;

    address public constant ROUTER_ADDR = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address public constant FACTORY_ADDR = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address public constant WETH_ADDR = 0xc778417E063141139Fce010982780140Aa0cD5Ab;
    address public constant DAI_ADDR = 0xc7AD46e0b8a400Bb3C915120d284AafbA8fc4735;
    address public constant REWARD_TOKEN_ADDR = 0x4aacB7f0bA0A5CfF9A8a5e8C0F24626Ee9FDA4a6;

    uint public constant CYCLE_LENGTH = 1 minutes;
    uint public constant REWARD_PER_CYCLE = 1000000 * 1e18; // 1 million tokens per week;

    struct Pool {
        uint8 nonce;
        address[] path;
        uint rewardPerShare;
        uint totalSharesPerCycle;
        uint currentCycleStartingTime;
        uint balance;
        bytes8[] traderSig;
    }

    mapping(address => uint) public totalGas;
    Pool[] public pools;

    mapping(address => uint) public rewards;
    

    struct Trader {
        address traderAddr;
        uint value;
        uint8 farming;
    }

    constructor () public {
        addPool(WETH_ADDR, DAI_ADDR);
    }

    function addPool(address inputToken, address outputToken) public {
        Pool memory p;
        
        p.path = new address[](2);
        p.path[0] = inputToken;
        p.path[1] = outputToken;

        p.rewardPerShare = 1;
        p.totalSharesPerCycle = 0;
        p.balance = 0;
        p.nonce = 0;
        p.currentCycleStartingTime = now;
        pools.push(p);
    }

    function getPoolInfo(uint8 poolId) external view returns (uint, uint) {
        return (pools[poolId].balance, pools[poolId].traderSig.length);
    }

    function deposit(uint8 poolId, uint val) external payable {
        // must >= 0.01 eth
        //require(msg.value >= 10000000000000000, "Minimum 0.01 ETH deposit");
        //require(traderSig.length < 256, "Exceed max number of traders");
        Pool storage pool = pools[poolId];
        if(pool.path[0] == WETH_ADDR) {
            pool.traderSig.push(bytes8(keccak256(abi.encodePacked(msg.sender, msg.value, pool.nonce))));
        } else {
            // deposit erc20 token
            IERC20(pool.path[0]).transferFrom(msg.sender, address(this), val);
            pool.traderSig.push(bytes8(keccak256(abi.encodePacked(msg.sender, val, pool.nonce))));
        }
    }

    function refund(uint8 poolId, uint idx, uint value) external {
        Pool storage pool = pools[poolId];
        require(pool.traderSig[idx] == bytes8(keccak256(abi.encodePacked(msg.sender, value, pool.nonce))), "Sig not matched");
        pool.traderSig[idx] = bytes8(0);
        if(pool.path[0] == WETH_ADDR) {
            msg.sender.transfer(value);
        } else {
            // erc20 token
            IERC20(pool.path[0]).transfer(msg.sender, value);
        }
    }

    function redeemRewards() external returns (uint) {
        uint rewardTokens = rewards[msg.sender].div(1e12);
        rewards[msg.sender] = 0;
        IERC20(REWARD_TOKEN_ADDR).transfer(msg.sender, rewardTokens);
    }

    function getTraderData(bytes memory data) internal pure returns(Trader[] memory traders, uint16 gasPrice) {
        // exclude path and gasPrice
        uint8 numTrader = toUint8(data, 0);

        gasPrice = toUint16(data, 1);

        traders = new Trader[](numTrader);

        // unpack trader array
        uint traderAddrStartAt = 3;
        uint valueStartAt = traderAddrStartAt + numTrader * 20;


        for(uint8 i = 0; i < numTrader; i++) {
            traders[i].traderAddr = toAddress(data, traderAddrStartAt);
            traders[i].value = toUint256(data, valueStartAt);

            traderAddrStartAt += 20;
            valueStartAt += 32;
        }
    }

    function parseTraderData(bytes memory data) public returns (bytes memory, uint8, address[] memory, uint[] memory, uint16) {
        uint8 numTrader = toUint8(data, 0);
        (Trader[] memory traders, uint16 gasPrice) = getTraderData(data);
        address[] memory traderAddr = new address[](traders.length);
        uint[] memory value = new uint[](traders.length);
        for (uint i = 0; i< traders.length; i++) {
            traderAddr[i] = traders[i].traderAddr;
            value[i] = traders[i].value;
        }
        return (data, numTrader, traderAddr, value, gasPrice);
    }

    function toAddress(bytes memory _bytes, uint256 _start) internal pure returns (address) {
        address tempAddress;

        assembly {
            tempAddress := div(mload(add(add(_bytes, 0x20), _start)), 0x1000000000000000000000000)
        }

        return tempAddress;
    }

    function toUint8(bytes memory _bytes, uint256 _start) internal pure returns (uint8) {
        require(_bytes.length >= (_start + 1), "Read out of bounds");
        uint8 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x1), _start))
        }

        return tempUint;
    }

    function toUint256(bytes memory _bytes, uint256 _start) internal pure returns (uint256) {
        uint256 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x20), _start))
        }

        return tempUint;
    }

    function toUint16(bytes memory _bytes, uint256 _start) internal pure returns (uint16) {
        uint16 tempUint;

        assembly {
            tempUint := mload(add(add(_bytes, 0x2), _start))
        }

        return tempUint;
    }


    function execute(uint8 poolId, bytes calldata data) external onlyOwner {
        (Trader[] memory traders,  uint16 gasPrice) = getTraderData(data);
        Pool storage pool = pools[poolId];

        uint poolBal = 0;
        for(uint i = 0; i < traders.length; i++) {
            if (pool.traderSig[i] == bytes8(0)) continue;
            poolBal += traders[i].value;
        }
        
        // assure gasPrice is within normal range (<= 2000 gwei)
        require(gasPrice <= 200000000000, "Exceed max gas price");
        
        uint gasCostInOutputTokens = getGasCost(traders.length, gasPrice, pool.path[1]);

        // cumulate gas cost in output tokens
        totalGas[pool.path[1]] = totalGas[pool.path[1]].add(gasCostInOutputTokens);

        // execute swap
        uint totalReceived = swap(pool.path, poolBal);

        // distribute to first trader with gas reimbursement
        if (pool.traderSig[0] != bytes8(0)) {
            require(bytes8(keccak256(abi.encodePacked(traders[0].traderAddr, traders[0].value, pool.nonce))) == pool.traderSig[0], "Sig not matched");
            distribute(traders[0], pool.path[1], poolBal, totalReceived);
            totalReceived = totalReceived.sub(gasCostInOutputTokens);
            poolBal = poolBal.sub(traders[0].value);
        }

        // distribute to the rest
        for(uint8 i = 1; i < traders.length; i++) {
            // ignore cancelled trades
            if (pool.traderSig[i] == bytes8(0)) continue;

            // verify sig
            require(bytes8(keccak256(abi.encodePacked(traders[i].traderAddr, traders[i].value, pool.nonce))) == pool.traderSig[i], "Sig not matched");
    
            // distribute output tokens
            distribute(traders[i], pool.path[1], poolBal, totalReceived);
        }

        // farming
        for(uint8 i = 0; i < traders.length; i++) {
            // ignore cancelled trades
            if (pool.traderSig[i] == bytes8(0)) continue;
            rewards[traders[i].traderAddr] = rewards[traders[i].traderAddr].add(pool.rewardPerShare.mul(traders[i].value));
            pool.totalSharesPerCycle = pool.totalSharesPerCycle.add(traders[i].value);
        }


        // prepare for the next batch
        delete pool.traderSig;
        pool.nonce += 1;
    }

    function getGasCost(uint numTraders, uint gasPrice, address outputTokenAddr) internal view returns (uint) {
        address[] memory gasPath = new address[](2);
        gasPath[0] = WETH_ADDR;
        gasPath[1] = outputTokenAddr;

        // gasPerTrader * numTrader * gasPrice = gas cost in wei
        // 43079 gas per trader on average
        // minus gas fees
        uint gasCost = numTraders.mul(gasPrice).mul(43079);
        uint[] memory amountsOut = UniswapV2Library.getAmountsOut(FACTORY_ADDR, gasCost, gasPath);
        uint gasCostInOutputTokens = amountsOut[1];
        return gasCostInOutputTokens;
    }

    function swap(address[] memory path, uint totalVal) internal returns (uint) {
        uint[] memory outputs;
        if (path[0] == WETH_ADDR) {
            // eth -> token
            outputs = IUniswapV2Router02(ROUTER_ADDR).swapExactETHForTokens{value: totalVal}(1, path, address(this), 1699853824);
        } else if (path[1] == WETH_ADDR) {
            // token -> eth
            outputs = IUniswapV2Router02(ROUTER_ADDR).swapExactTokensForETH(totalVal, 1, path, address(this), 1699853824);
        } else {
            // token -> token
            outputs = IUniswapV2Router02(ROUTER_ADDR).swapExactTokensForTokens(totalVal, 1, path, address(this), 1699853824);
        }
        return outputs[1];
    }

    function distribute(Trader memory trader, address outputToken, uint totalVal, uint totalReceived) internal {
            uint transferAmount = trader.value.mul(totalReceived).div(totalVal);
            if(outputToken != WETH_ADDR) {
                IERC20(outputToken).transfer(trader.traderAddr, transferAmount);
            } else {
                payable(trader.traderAddr).transfer(transferAmount);
            }
    }

    function updateCycle(uint8 poolId) external {
        Pool storage pool = pools[poolId];
        require(now > pool.currentCycleStartingTime + CYCLE_LENGTH, "Current cycle not finished"); 

        // update reward per share
        pool.rewardPerShare = REWARD_PER_CYCLE.mul(1e12).div(pool.totalSharesPerCycle);
        if (pool.rewardPerShare > 1000) pool.rewardPerShare = 1000;
        
        pool.currentCycleStartingTime = now;
    }

    function withdrawGasFees(address tokenAddr) external onlyOwner {
        if (tokenAddr == address(0x0)) {
            msg.sender.transfer(totalGas[tokenAddr]);
        } else {
            address[] memory path = new address[](2);
            path[1] = WETH_ADDR;
            path[0] = tokenAddr;
            IUniswapV2Router02(ROUTER_ADDR).swapExactTokensForETH(totalGas[tokenAddr], 1, path, msg.sender, 1699853824);
        }
        totalGas[tokenAddr] = 0;
    }
}
