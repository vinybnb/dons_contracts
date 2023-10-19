// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockERC721 is ERC721 {
    constructor() ERC721("MockERC721", "MockERC721") {
    }

    function mint(address _to, uint256 _tokenId) public {
        _mint(_to, _tokenId);
    }

    function mintBatch(address _to, uint256 _quantity) public {
        for (uint256 i = 0; i < _quantity; i++) {
            _mint(_to, i);
        }
    }
}