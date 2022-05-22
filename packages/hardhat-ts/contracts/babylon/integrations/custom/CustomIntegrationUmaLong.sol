// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.7.6;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IBabController } from "../../interfaces/IBabController.sol";
import { IStrategy } from "../../interfaces/IStrategy.sol";
import { CustomIntegration } from "./CustomIntegration.sol";
import { PreciseUnitMath } from "../../lib/PreciseUnitMath.sol";
import { LowGasSafeMath } from "../../lib/LowGasSafeMath.sol";
import { BytesLib } from "../../lib/BytesLib.sol";
import { ControllerLib } from "../../lib/ControllerLib.sol";

import { ILongShortPair } from "../../../interface-uma/ILongShortPair.sol";
import { ExpandedIERC20 } from "../../../interface-uma/ExpandedIERC20.sol";
import { CustomIntegrationUmaLongShortPair } from "./CustomIntegrationUmaLongShortPair.sol";

import { ISwapRouter } from "../../interfaces/external/uniswap-v3/ISwapRouter.sol";

/**
 * @title CustomIntegrationSample
 * @author Babylon Finance Protocol
 *
 * Custom integration template
 */
contract CustomIntegrationUmaLong is CustomIntegrationUmaLongShortPair {
  using LowGasSafeMath for uint256;
  using PreciseUnitMath for uint256;
  using BytesLib for uint256;
  using ControllerLib for IBabController;

  constructor(IBabController _controller) CustomIntegrationUmaLongShortPair(_controller) {
    require(address(_controller) != address(0), "invalid address");
  }

  /**
   * (OPTIONAL) Return post action calldata
   *
   * hparam  _strategy                 Address of the strategy
   * hparam  _asset                    Address param
   * hparam  _amount                   Amount
   * hparam  _customOp                 Type of op
   *
   * @return address                   Target contract address
   * @return uint256                   Call value
   * @return bytes                     Trade calldata
   */
  function _getPostActionCallData(
    address _strategy,
    address _asset,
    uint256, /* _amount */
    uint256 _customOp
  )
    internal
    view
    override
    returns (
      address,
      uint256,
      bytes memory
    )
  {
    // only execute the action after entering the strategy
    if (_customOp != 0) {
      return (address(0), 0, bytes(""));
    }

    //  trading the short token

    // Not trading the short/long token because theres not enough liquidity on mainnet

    ILongShortPair token = ILongShortPair(_asset);
    ExpandedIERC20 shortToken = ExpandedIERC20(token.shortToken());
    uint256 myBalance = shortToken.balanceOf(_strategy);
    address collateralToken = address(token.collateralToken());

    bytes memory selector = abi.encodeWithSelector(
      ISwapRouter.exactInputSingle.selector,
      address(shortToken),
      address(collateralToken),
      500,
      address(this),
      block.timestamp,
      myBalance,
      0,
      0
    );

    return (0xE592427A0AEce92De3Edee1F18E0157C05861564, 0, selector);
    // return (address(0), 0, bytes(""));
  }

  function _postActionNeedsApproval(
    address _asset,
    uint8 /* _customOp */
  ) internal view override returns (address, address) {
    ILongShortPair token = ILongShortPair(_asset);
    ExpandedIERC20 shortToken = ExpandedIERC20(token.shortToken());

    return (address(shortToken), 0xE592427A0AEce92De3Edee1F18E0157C05861564);
  }
}
