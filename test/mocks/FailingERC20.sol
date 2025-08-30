// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FailingERC20 is ERC20 {
    constructor() ERC20("FailingToken", "FAIL") {}

    function transfer(address, uint256) public pure override returns (bool) {
        return false; // always fails
    }
}
