// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract OrgToken is ERC20 {
    address public owner;

    constructor(uint256 initialSupply) ERC20("OrgToken", "ORG") {
        owner = msg.sender;
        _mint(msg.sender, initialSupply);
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == owner, "only owner");
        _mint(to, amount);
    }
}
