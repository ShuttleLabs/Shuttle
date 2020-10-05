pragma solidity ^0.6.6;
pragma experimental ABIEncoderV2;

import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import '@uniswap/v2-periphery/contracts/interfaces/IERC20.sol';
import '@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol';
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GasExpressPool is Ownable {
    using SafeMath for uint256;

    address public constant ROUTER_ADDR = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address public constant FACTORY_ADDR = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address public constant WETH_ADDR = 0xc778417E063141139Fce010982780140Aa0cD5Ab;
    address public constant DAI_ADDR = 0xc7AD46e0b8a400Bb3C915120d284AafbA8fc4735;
    address public constant REWARD_TOKEN_ADDR = 0x4aacB7f0bA0A5CfF9A8a5e8C0F24626Ee9FDA4a6;

    uint public constant CYCLE_LENGTH = 1 minutes;
    uint public constant REWARD_PER_CYCLE = 1000000 * 1e18; // 1 million tokens per week;

    // global var
    uint public rewardPerShare = 100;
    uint public totalSharesPerCycle;
    uint public currentCycleStartingTime;
    mapping(address => uint) public totalGas;
    

    bytes8[] public traderSig;
    mapping(address => uint) public rewards;
    uint8 nonce;

    struct Trader {
        address traderAddr;
        uint value;
        uint8 farming;
    }

    constructor () public {
        currentCycleStartingTime = now;
    }

    function deposit(bool farming) external payable {
        // must >= 0.01 eth
        require(msg.value >= 10000000000000000, "Minimum 0.01 ETH deposit");
        require(traderSig.length < 256, "Exceed max number of traders");
        traderSig.push(bytes8(keccak256(abi.encodePacked(msg.sender, msg.value, farming, nonce))));
    }

    function refund(uint idx, uint value, bool farming) external {
        require(traderSig[idx] == bytes8(keccak256(abi.encodePacked(msg.sender, value, farming, nonce))), "Sig not matched");
        traderSig[idx] = bytes8(0);
        msg.sender.transfer(value);
    }

    function redeemRewards() external returns (uint) {
        uint rewardTokens = rewards[msg.sender].div(1e12);
        rewards[msg.sender] = 0;
        IERC20(REWARD_TOKEN_ADDR).transfer(msg.sender, rewardTokens);
        //sushi.mint(devaddr, sushiReward.div(10))
        // sushi.mint(address(this), sushiReward)
    }

    function getTraderData(bytes memory data) internal pure returns(Trader[] memory traders, address[] memory path, uint16 gasPrice) {
        // exclude path and gasPrice
        uint8 numTrader = toUint8(data, 0);
    
        path = new address[](2);
        path[0] = toAddress(data, 1);
        path[1] = toAddress(data, 21);

        gasPrice = toUint16(data, 41);

        traders = new Trader[](numTrader);

        // unpack trader array
        uint traderAddrStartAt = 43;
        uint valueStartAt = traderAddrStartAt + numTrader * 20;
        uint farmingStartAt = valueStartAt + numTrader * 32; 

        for(uint8 i = 0; i < numTrader; i++) {
            traders[i].traderAddr = toAddress(data, traderAddrStartAt);
            traders[i].value = toUint256(data, valueStartAt);
            traders[i].farming = toUint8(data, farmingStartAt);

            traderAddrStartAt += 20;
            valueStartAt += 32;
            farmingStartAt += 1;
        }
    }

    function parseTraderData(bytes memory data) public returns (bytes memory, uint8, address[] memory, uint[] memory, uint8[] memory, address[] memory, uint16) {
        uint8 numTrader = toUint8(data, 0);
        (Trader[] memory traders, address[] memory path, uint16 gasPrice) = getTraderData(data);
        address[] memory traderAddr = new address[](traders.length);
        uint[] memory value = new uint[](traders.length);
        uint8[] memory farming = new uint8[](traders.length);
        for (uint i = 0; i< traders.length; i++) {
            traderAddr[i] = traders[i].traderAddr;
            value[i] = traders[i].value;
            farming[i] = traders[i].farming;
        }
        return (data, numTrader, traderAddr, value, farming, path, gasPrice);
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


    function execute(bytes calldata data) external onlyOwner {
        (Trader[] memory traders, address[] memory path, uint16 gasPrice) = getTraderData(data);

        
        // assure gasPrice is within normal range (<= 2000 gwei)
        require(gasPrice <= 200000000000, "Exceed max gas price");
        
        uint totalVal = 0;
        for(uint8 i = 0; i < traders.length; i++) {
            // ignore cancelled trades
            if (traderSig[i] == bytes8(0)) continue;

            totalVal = totalVal.add(traders[i].value);
        }

        uint gasCostInOutputTokens = getGasCost(traders.length, gasPrice, path[1]);

        // cumulate gas cost in input tokens
        totalGas[path[0]] = totalGas[path[0]].add(gasCostInOutputTokens);

        // execute swap
        uint totalReceived = swap(path, totalVal);

        // tracking remaining output balance as we
        // distribute output tokens to traders
        uint bal = totalReceived;

        for(uint8 i = 0; i < traders.length; i++) {
            // ignore cancelled trades
            if (traderSig[i] == bytes8(0)) continue;

            // verify sig
            require(bytes8(keccak256(abi.encodePacked(traders[i].traderAddr, traders[i].value, traders[i].farming, nonce))) == traderSig[i], "Sig not matched");
    
            // distribute output tokens
            bal = distribute(traders[i], totalVal, totalReceived, bal, i == traderSig.length - 1);

            if (i == 0) {
                // no gas cost for the first trader
                totalReceived = bal.sub(gasCostInOutputTokens);
                totalVal = totalVal.sub(traders[0].value);
            }

            if (traders[i].farming != uint8(0)) {
                // yield farming
                rewards[traders[i].traderAddr] = rewards[traders[i].traderAddr].add(rewardPerShare.mul(traders[i].value));
                totalSharesPerCycle = totalSharesPerCycle.add(traders[i].value);
            }
        }

        // prepare for the next batch
        delete traderSig;
        nonce += 1;
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

    function distribute(Trader memory trader, uint totalVal, uint totalReceived, uint bal, bool isLast) internal returns(uint) {
            if (!isLast) {
                uint transferAmount = trader.value.mul(totalReceived).div(totalVal);
                bal = bal.sub(transferAmount);
                IERC20(DAI_ADDR).transfer(trader.traderAddr, transferAmount);
            } else {
                IERC20(DAI_ADDR).transfer(trader.traderAddr, bal);
                bal = 0;
            }

            return bal;
    }

    function updateCycle() external {
        require(now > currentCycleStartingTime + CYCLE_LENGTH, "Current cycle not finished"); 

        // update reward per share
        rewardPerShare = REWARD_PER_CYCLE.mul(1e12).div(totalSharesPerCycle);
        currentCycleStartingTime = now;
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
