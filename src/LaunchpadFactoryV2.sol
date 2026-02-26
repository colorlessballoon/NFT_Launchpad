// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./LaunchpadFactory.sol";

contract LaunchpadFactoryV2 is LaunchpadFactory {
    function version() public pure returns (string memory) {
        return "V2";
    }
}
