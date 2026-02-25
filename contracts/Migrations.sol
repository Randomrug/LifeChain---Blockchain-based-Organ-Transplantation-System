// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

contract Migrations {
    address public owner;
    uint public last_completed_migration;

    constructor() {
        owner = msg.sender;
    }

    function setCompleted(uint completed) public {
        require(msg.sender == owner, "only owner can call");
        last_completed_migration = completed;
    }
}
