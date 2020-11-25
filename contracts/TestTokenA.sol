pragma solidity ^0.6.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestTokenA is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) public {
        _mint(msg.sender, 1e28);
    }
}