// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    uint8 private _decimals;
    constructor(uint8 decimals_) ERC20("MockERC20", "MockERC20") {
        _mint(msg.sender, 100_000_000 * 10 ** _decimals);
        _decimals = decimals_;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address _to, uint256 _amount) public {
        _mint(_to, _amount);
    }
}
