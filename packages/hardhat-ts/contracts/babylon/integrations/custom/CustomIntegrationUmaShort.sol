// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.7.6;

import { IBabController } from "../../interfaces/IBabController.sol";
import { CustomIntegrationUmaLongShortPair } from "./CustomIntegrationUmaLongShortPair.sol";

/**
 * @title Custom integration for the UMA Long Short Pair
 * @author ChrisiPK, MartelAxe
 *
 * This integration allows Babylon Finance gardens to connect to a UMA Long short pair.
 * The long token of the pair will be swapped away and only the short token will be kept.
 */
contract CustomIntegrationUmaShort is CustomIntegrationUmaLongShortPair {
  constructor(IBabController _controller) CustomIntegrationUmaLongShortPair(_controller, true) {}
}
