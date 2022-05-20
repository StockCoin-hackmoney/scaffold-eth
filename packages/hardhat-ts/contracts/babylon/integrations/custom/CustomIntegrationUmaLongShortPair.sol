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

import { IUniswapV2Router } from "../../interfaces/external/uniswap/IUniswapV2Router.sol";

import "hardhat/console.sol";

/**
 * @title CustomIntegrationSample
 * @author Babylon Finance Protocol
 *
 * Custom integration template
 */
contract CustomIntegrationUmaLongShortPair is CustomIntegration {
  using LowGasSafeMath for uint256;
  using PreciseUnitMath for uint256;
  using BytesLib for uint256;
  using ControllerLib for IBabController;

  /* ============ State Variables ============ */

  /* Add State variables here if any. Pass to the constructor */

  /* ============ Constructor ============ */

  /**
   * Creates the integration
   *
   * @param _controller                   Address of the controller
   */
  constructor(IBabController _controller) CustomIntegration("custom_uma_longshortpair_sample", _controller) {
    require(address(_controller) != address(0), "invalid address");
  }

  /* =============== Internal Functions ============== */

  /**
   * Whether or not the data provided is valid
   *
   * hparam  _data                     Data provided
   * @return bool                      True if the data is correct
   */
  function _isValid(bytes memory _data) internal view override returns (bool) {
    // Check if the UMA token is not expired

    return _isUmaTokenNotExpired(_data);
  }

  function _isUmaTokenNotExpired(bytes memory _data) private view returns (bool) {
    ILongShortPair token = _getUmaTokenFromBytes(_data);
    console.log("contractState", uint256(token.contractState()));
    return uint256(token.contractState()) == 0;
  }

  function _isUmaTokenExpiredPriceReceived(bytes memory _data) private view returns (bool) {
    ILongShortPair token = _getUmaTokenFromBytes(_data);
    return uint256(token.contractState()) == 2;
  }

  function _getUmaTokenFromBytes(bytes memory _data) private pure returns (ILongShortPair) {
    address umaToken = address(BytesLib.decodeOpDataAddressAssembly(_data, 12));
    ILongShortPair token = ILongShortPair(umaToken);
    return token;
  }

  /**
   * Which address needs to be approved (IERC-20) for the input tokens.
   *
   * hparam  _data                     Data provided
   * hparam  _opType                   O for enter, 1 for exit
   * @return address                   Address to approve the tokens to
   */
  function _getSpender(
    bytes calldata _data,
    uint8 /* _opType */
  ) internal pure override returns (address) {
    return address(BytesLib.decodeOpDataAddressAssembly(_data, 12));
  }

  /**
   * The address of the IERC-20 token obtained after entering this operation
   *
   * @param  _token                     Address provided as param
   * @return address                    Address of the resulting lp token
   */
  function _getResultToken(address _token) internal view override returns (address) {
    // TODO find out how we can return long and short tokens here!
    ILongShortPair token = ILongShortPair(_token);
    return address(token.longToken());
  }

  /**
   * Return enter custom calldata
   *
   * hparam  _strategy                 Address of the strategy
   * hparam  _data                     OpData e.g. Address of the pool
   * hparam  _resultTokensOut          Amount of result tokens to send
   * hparam  _tokensIn                 Addresses of tokens to send to spender to enter
   * hparam  _maxAmountsIn             Amounts of tokens to send to spender
   *
   * @return address                   Target contract address
   * @return uint256                   Call value
   * @return bytes                     Trade calldata
   */
  function _getEnterCalldata(
    address, /* _strategy */
    bytes calldata _data,
    uint256, /* _resultTokensOut */
    address[] calldata _tokensIn,
    uint256[] calldata _maxAmountsIn
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
    console.log(_tokensIn[0]);
    console.log(_maxAmountsIn[0]);
    require(_isUmaTokenNotExpired(_data), "Cannot send tokens to expired UMA token!");
    address umaToken = address(BytesLib.decodeOpDataAddressAssembly(_data, 12));
    ILongShortPair token = ILongShortPair(umaToken);

    // address longToken = address(token.longToken());

    require(_tokensIn.length == 1 && _maxAmountsIn.length == 1, "Wrong amount of tokens provided");
    // check how to send the correct collateral in test
    console.log("collateralToken", address(token.collateralToken()));

    console.log("collateralPair", token.collateralPerPair());
    require(_tokensIn[0] == address(token.collateralToken()), "Wrong token selected to send as collateral!");
    uint256 amountTokensToCreate = ((_maxAmountsIn[0]) * 10**18) / token.collateralPerPair();
    console.log("amountTokensToCreate", amountTokensToCreate);
    require(amountTokensToCreate > 0, "not enough tokens supplied!");
    bytes memory methodData = abi.encodeWithSelector(ILongShortPair.create.selector, amountTokensToCreate);

    return (umaToken, 0, methodData);
  }

  /**
   * Return exit custom calldata
   *
   * hparam  _strategy                 Address of the strategy
   * hparam  _data                     OpData e.g. Address of the pool
   * hparam  _resultTokensIn           Amount of result tokens to send
   * hparam  _tokensOut                Addresses of tokens to receive
   * hparam  _minAmountsOut            Amounts of input tokens to receive
   *
   * @return address                   Target contract address
   * @return uint256                   Call value
   * @return bytes                     Trade calldata
   */
  function _getExitCalldata(
    address, /* _strategy */
    bytes calldata _data,
    uint256 _resultTokensIn,
    address[] calldata, /* _tokensOut */
    uint256[] calldata /* _minAmountsOut */
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
    require(_isUmaTokenExpiredPriceReceived(_data), "Cannot exit before the token is expired and price has been received!");
    // ILongShortPair token = _getUmaTokenFromBytes(_data); // this is not needed we get the address from data
    bytes memory methodData = abi.encodeWithSelector(ILongShortPair.settle.selector, _resultTokensIn, _resultTokensIn);
    return (address(BytesLib.decodeOpDataAddressAssembly(_data, 12)), 0, methodData);
  }

  /**
   * The list of addresses of the IERC-20 tokens mined as rewards during the strategy
   *
   * hparam  _data                      Address provided as param
   * @return address[] memory           List of reward token addresses
   */
  function _getRewardTokens(
    address /* _data */
  ) internal pure override returns (address[] memory) {
    // No rewards
    return new address[](1);
  }

  /* ============ External Functions ============ */

  /**
   * The tokens to be purchased by the strategy on enter according to the weights.
   * Weights must add up to 1e18 (100%)
   *
   * hparam  _data                      Address provided as param
   * @return _inputTokens               List of input tokens to buy
   * @return _inputWeights              List of weights for the tokens to buy
   */
  function getInputTokensAndWeights(bytes calldata _data) external view override returns (address[] memory _inputTokens, uint256[] memory _inputWeights) {
    address umaToken = address(BytesLib.decodeOpDataAddressAssembly(_data, 12));
    ILongShortPair token = ILongShortPair(umaToken);

    console.log("returned Address", address(token.collateralToken()));

    address[] memory inputTokens = new address[](1);
    inputTokens[0] = address(token.collateralToken());
    uint256[] memory inputWeights = new uint256[](1);
    inputWeights[0] = 1e18; // 100%
    return (inputTokens, inputWeights);
  }

  /**
   * The tokens to be received on exit.
   *
   * hparam  _data                      Bytes data
   * hparam  _liquidity                 Number with the amount of result tokens to exit
   * @return exitTokens                 List of output tokens to receive on exit
   * @return _minAmountsOut             List of min amounts for the output tokens to receive
   */
  function getOutputTokensAndMinAmountOut(
    bytes calldata _data,
    uint256 /* _liquidity */
  ) external view override returns (address[] memory exitTokens, uint256[] memory _minAmountsOut) {
    address umaToken = address(BytesLib.decodeOpDataAddressAssembly(_data, 12));
    ILongShortPair token = ILongShortPair(umaToken);
    address[] memory exitTokens = new address[](1);
    exitTokens[0] = address(token.collateralToken());
    uint256[] memory minAmountsOut = new uint256[](1);
    minAmountsOut[0] = 0;
    return (exitTokens, minAmountsOut);
  }

  /**
   * The price of the result token based on the asset received on enter
   *
   * hparam  _data                      Bytes data
   * hparam  _tokenDenominator          Token we receive the capital in
   * @return uint256                    Amount of result tokens to receive
   */
  // function getPriceResultToken(
  //   bytes calldata _data,
  //   address _tokenDenominator
  // ) external pure override returns (uint256) {
  //   LongShortPair token = _getUmaTokenFromBytes(_data);
  //   require(_tokenDenominator == token.collateralToken, "Cannot give price in other denominator than in collateral token!");
  //   return token.collateralPerPair;
  // }

  function getPriceResultToken(
    bytes calldata, /* _data */
    address /* _tokenDenominator */
  ) external pure override returns (uint256) {
    /** FILL THIS */
    return 0;
  }

  /**
   * (OPTIONAL). Return pre action calldata
   *
   * hparam _strategy                  Address of the strategy
   * hparam  _asset                    Address param
   * hparam  _amount                   Amount
   * hparam  _customOp                 Type of Custom op
   *
   * @return address                   Target contract address
   * @return uint256                   Call value
   * @return bytes                     Trade calldata
   */
  function _getPreActionCallData(
    address, /* _strategy */
    address, /* _asset */
    uint256, /* _amount */
    uint256 /* _customOp */
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
    return (address(0), 0, bytes(""));
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

    // ILongShortPair token = ILongShortPair(_asset);
    // ExpandedIERC20 shortToken = ExpandedIERC20(token.shortToken());
    // uint256 myBalance = shortToken.balanceOf(_strategy);
    // address collateralToken = address(token.collateralToken());

    // bytes memory selector = abi.encodeWithSelector(
    //   IUniswapV2Router.swapExactTokensForTokens.selector,
    //   1,
    //   0,
    //   [0xdAC17F958D2ee523a2206206994597C13D831ec7, collateralToken],
    //   0x47ac0Fb4F2D84898e4D9E7b4DaB3C24507a6D503,
    //   block.timestamp
    // );

    // return (0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D, 0, selector);

    return (address(0), 0, bytes(""));
  }

  /**
   * (OPTIONAL). Whether or not the pre action needs an approval.
   * Only makes sense if _getPreActionCallData is filled.
   *
   * hparam  _asset                     Asset passed as param
   * hparam  _tokenDenominator          0 for enter, 1 for exit
   * @return address                    Address of the asset to approve
   * @return address                    Address to approve
   */
  function _preActionNeedsApproval(
    address, /* _asset */
    uint8 /* _customOp */
  ) internal view override returns (address, address) {
    return (address(0), address(0));
  }

  /**
   * (OPTIONAL). Whether or not the post action needs an approval
   * Only makes sense if _getPostActionCallData is filled.
   *
   * hparam  _asset                     Asset passed as param
   * hparam  _tokenDenominator          0 for enter, 1 for exit
   * @return address                    Address of the asset to approve
   * @return address                    Address to approve
   */
  function _postActionNeedsApproval(
    address _asset,
    uint8 /* _customOp */
  ) internal view override returns (address, address) {
    ILongShortPair token = ILongShortPair(_asset);
    ExpandedIERC20 shortToken = ExpandedIERC20(token.shortToken());

    address uniswapShortTokenAddress = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    return (address(shortToken), 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
  }
}
