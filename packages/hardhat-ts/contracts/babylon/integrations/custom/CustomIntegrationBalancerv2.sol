// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;
import { IERC20 } from "@balancer-labs/v2-solidity-utils/contracts/openzeppelin/IERC20.sol";
import { IBabController } from "../../interfaces/IBabController.sol";
import { CustomIntegration } from "./CustomIntegration.sol";
import { PreciseUnitMath } from "../../lib/PreciseUnitMath.sol";
import { LowGasSafeMath } from "../../lib/LowGasSafeMath.sol";
import { BytesLib } from "../../lib/BytesLib.sol";
import { ControllerLib } from "../../lib/ControllerLib.sol";
import { PoolBalances } from "@balancer-labs/v2-vault/contracts/PoolBalances.sol";

import { IVault } from "@balancer-labs/v2-vault/contracts/interfaces/IVault.sol";
import { IAsset } from "@balancer-labs/v2-vault/contracts/interfaces/IAsset.sol";
import { IBasePool } from "@balancer-labs/v2-vault/contracts/interfaces/IBasePool.sol";

import "hardhat/console.sol";

interface IMinimalPool {
  function getVault() external view returns (IVault);
}

interface IERC20Decimals {
  function decimals() external view returns (uint8);
}

/**
 * @title CustomIntegrationSample
 * @author Babylon Finance Protocol
 *
 * Custom integration template
 */
contract CustomIntegrationBalancerv2 is CustomIntegration {
  using LowGasSafeMath for uint256;
  using PreciseUnitMath for uint256;
  using BytesLib for uint256;
  using ControllerLib for IBabController;

  address constant vaultAddress = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

  /* ============ State Variables ============ */

  /* Add State variables here if any. Pass to the constructor */

  /* ============ Constructor ============ */

  /**
   * Creates the integration
   *
   * @param _controller                   Address of the controller
   */
  constructor(IBabController _controller) CustomIntegration("custom_balancerv2", _controller) {
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
    IMinimalPool pool = IMinimalPool(BytesLib.decodeOpDataAddressAssembly(_data, 12));

    return address(pool.getVault()) == vaultAddress;
  }

  /**
   * Which address needs to be approved (IERC-20) for the input tokens.
   *
   * hparam  _data                     Data provided
   * hparam  _opType                   O for enter, 1 for exit
   * @return address                   Address to approve the tokens to
   */
  function _getSpender(
    bytes calldata, /*_data*/
    uint8 /* _opType */
  ) internal pure override returns (address) {
    return vaultAddress;
  }

  /**
   * The address of the IERC-20 token obtained after entering this operation
   *
   * @param  _token                     Address provided as param
   * @return address                    Address of the resulting lp token
   */
  function _getResultToken(address _token) internal pure override returns (address) {
    return _token;
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
    address _strategy,
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
    bytes32 poolId = IBasePool(BytesLib.decodeOpDataAddress(_data)).getPoolId();

    address strategy = _strategy;

    (IERC20[] memory tokens, , ) = IVault(vaultAddress).getPoolTokens(poolId);
    require(_tokensIn.length == tokens.length, "Must supply same number of tokens as are already in the pool!");

    IVault.JoinPoolRequest memory joinRequest = getJoinRequest(_tokensIn, tokens, _maxAmountsIn);

    // struct JoinPoolRequest {
    //     IAsset[] assets;
    //     uint256[] maxAmountsIn;
    //     bytes userData;
    //     bool fromInternalBalance;
    // }

    bytes memory methodData = abi.encodeWithSelector(IVault.joinPool.selector, poolId, strategy, strategy, joinRequest);

    return (vaultAddress, 0, methodData);
  }

  function getJoinRequest(
    address[] calldata _tokensIn,
    IERC20[] memory tokens,
    uint256[] calldata _maxAmountsIn
  ) private view returns (IVault.JoinPoolRequest memory joinRequest) {
    joinRequest.maxAmountsIn = new uint256[](_tokensIn.length);
    joinRequest.assets = new IAsset[](tokens.length);

    for (uint8 i = 0; i < tokens.length; ++i) {
      joinRequest.assets[i] = IAsset(address(tokens[i]));
      for (uint8 k = 0; k < _maxAmountsIn.length; ++k) {
        if (_tokensIn[k] == address(tokens[i])) {
          joinRequest.maxAmountsIn[i] = _maxAmountsIn[k];
          break;
        }
      }
    }

    joinRequest.userData = abi.encode(
      uint256(1), /* EXACT_TOKENS_IN_FOR_BPT_OUT */
      joinRequest.maxAmountsIn,
      uint256(0) /* minimum BPT amount */
    );

    return joinRequest;
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
    bytes calldata, /* _data */
    uint256, /* _resultTokensIn */
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
    /** FILL THIS */
    return (address(0), 0, bytes(""));
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
    // No extra rewards.

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
    IBasePool pool = IBasePool(BytesLib.decodeOpDataAddressAssembly(_data, 12));
    IVault vault = IVault(vaultAddress);
    bytes32 poolId = pool.getPoolId();

    (IERC20[] memory tokens, uint256[] memory balances, uint256 lastBlock) = vault.getPoolTokens(poolId);

    uint256 tokenBalanceTotal;
    _inputWeights = new uint256[](tokens.length);
    _inputTokens = new address[](tokens.length);

    for (uint8 i = 0; i < tokens.length; ++i) {
      tokenBalanceTotal += getBalanceFullDecimals(balances[i], tokens[i]);
    }
    for (uint8 i = 0; i < tokens.length; ++i) {
      _inputTokens[i] = address(tokens[i]);
      _inputWeights[i] = (getBalanceFullDecimals(balances[i], tokens[i]) * (10**18)) / tokenBalanceTotal;
      console.log("token", _inputTokens[i], "amount", _inputWeights[i]);
    }

    return (_inputTokens, _inputWeights);
  }

  function getBalanceFullDecimals(uint256 balance, IERC20 token) private view returns (uint256) {
    IERC20Decimals tokenMetadata = IERC20Decimals(address(token));
    if (tokenMetadata.decimals() != 0) {
      return balance * (10**(18 - tokenMetadata.decimals()));
    }

    // no information on decimals available, assume 18
    return balance;
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
    bytes calldata, /* _data */
    uint256 /* _liquidity */
  ) external pure override returns (address[] memory exitTokens, uint256[] memory _minAmountsOut) {
    /** FILL THIS */
    return (new address[](1), new uint256[](1));
  }

  /**
   * The price of the result token based on the asset received on enter
   *
   * hparam  _data                      Bytes data
   * hparam  _tokenDenominator          Token we receive the capital in
   * @return uint256                    Amount of result tokens to receive
   */
  function getPriceResultToken(
    bytes calldata, /* _data */
    address /* _tokenDenominator */
  ) external pure override returns (uint256) {
    /** FILL THIS */
    return 0;
  }
}
