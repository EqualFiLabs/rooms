// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.33;

import { LibReentrancy } from "../libraries/LibReentrancy.sol";

abstract contract Guarded {
    modifier nonReentrant() {
        LibReentrancy.enter();
        _;
        LibReentrancy.exit();
    }
}
