// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.7.6;

/**
 * @title Long Short Pair.
 * @notice Uses a combination of long and short tokens to tokenize the bounded price exposure to a given identifier.
 */

import "./ExpandedIERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ILongShortPair {
  /****************************************
   *                EVENTS                *
   ****************************************/

  event TokensCreated(address indexed sponsor, uint256 indexed collateralUsed, uint256 indexed tokensMinted);
  event TokensRedeemed(address indexed sponsor, uint256 indexed collateralReturned, uint256 indexed tokensRedeemed);
  event ContractExpired(address indexed caller);
  event EarlyExpirationRequested(address indexed caller, uint64 earlyExpirationTimeStamp);
  event PositionSettled(address indexed sponsor, uint256 collateralReturned, uint256 longTokens, uint256 shortTokens);

  enum ContractState {
    Open,
    ExpiredPriceRequested,
    ExpiredPriceReceived
  }

  // State functions (check if this works)

  function contractState() external view returns (ContractState _contractState);

  function longToken() external view returns (ExpandedIERC20 _longToken);

  function shortToken() external view returns (ExpandedIERC20 _shortToken);

  function collateralToken() external view returns (IERC20 _collateralToken);

  function collateralPerPair() external view returns (uint256 _collateralPerPair);

  /****************************************
   *          POSITION FUNCTIONS          *
   ****************************************/

  /**
   * @notice Creates a pair of long and short tokens equal in number to tokensToCreate. Pulls the required collateral
   * amount into this contract, defined by the collateralPerPair value.
   * @dev The caller must approve this contract to transfer `tokensToCreate * collateralPerPair` amount of collateral.
   * @param tokensToCreate number of long and short synthetic tokens to create.
   * @return collateralUsed total collateral used to mint the synthetics.
   */
  function create(uint256 tokensToCreate) external returns (uint256 collateralUsed);

  /**
   * @notice Redeems a pair of long and short tokens equal in number to tokensToRedeem. Returns the commensurate
   * amount of collateral to the caller for the pair of tokens, defined by the collateralPerPair value.
   * @dev This contract must have the `Burner` role for the `longToken` and `shortToken` in order to call `burnFrom`.
   * @dev The caller does not need to approve this contract to transfer any amount of `tokensToRedeem` since long
   * and short tokens are burned, rather than transferred, from the caller.
   * @dev This method can be called either pre or post expiration.
   * @param tokensToRedeem number of long and short synthetic tokens to redeem.
   * @return collateralReturned total collateral returned in exchange for the pair of synthetics.
   */
  function redeem(uint256 tokensToRedeem) external returns (uint256 collateralReturned);

  /**
   * @notice Settle long and/or short tokens in for collateral at a rate informed by the contract settlement.
   * @dev Uses financialProductLibrary to compute the redemption rate between long and short tokens.
   * @dev This contract must have the `Burner` role for the `longToken` and `shortToken` in order to call `burnFrom`.
   * @dev The caller does not need to approve this contract to transfer any amount of `tokensToRedeem` since long
   * and short tokens are burned, rather than transferred, from the caller.
   * @dev This function can be called before or after expiration to facilitate early expiration. If a price has
   * not yet been resolved for either normal or early expiration yet then it will revert.
   * @param longTokensToRedeem number of long tokens to settle.
   * @param shortTokensToRedeem number of short tokens to settle.
   * @return collateralReturned total collateral returned in exchange for the pair of synthetics.
   */
  function settle(uint256 longTokensToRedeem, uint256 shortTokensToRedeem) external returns (uint256 collateralReturned);

  /****************************************
   *        GLOBAL STATE FUNCTIONS        *
   ****************************************/

  /**
   * @notice Enables the LSP to request early expiration. This initiates a price request to the optimistic oracle at
   * the provided timestamp with a modified version of the ancillary data that includes the key "earlyExpiration:1"
   * which signals to the OO that this is an early expiration request, rather than standard settlement.
   * @dev The caller must approve this contract to transfer `proposerReward` amount of collateral.
   * @dev Will revert if: a) the contract is already early expired, b) it is after the expiration timestamp, c)
   * early expiration is disabled for this contract, d) the proposed expiration timestamp is in the future.
   * e) an early expiration attempt has already been made (in pending state).
   * @param _earlyExpirationTimestamp timestamp at which the early expiration is proposed.
   */
  function requestEarlyExpiration(uint64 _earlyExpirationTimestamp) external;

  /**
   * @notice Expire the LSP contract. Makes a request to the optimistic oracle to inform the settlement price.
   * @dev The caller must approve this contract to transfer `proposerReward` amount of collateral.
   * @dev Will revert if: a) the contract is already early expired, b) it is before the expiration timestamp or c)
   * an expire call has already been made.
   */
  function expire() external;

  /***********************************
   *      GLOBAL VIEW FUNCTIONS      *
   ***********************************/

  /**
   * @notice Returns the number of long and short tokens a sponsor wallet holds.
   * @param sponsor address of the sponsor to query.
   * @return longTokens the number of long tokens held by the sponsor.
   * @return shortTokens the number of short tokens held by the sponsor.
   */
  function getPositionTokens(address sponsor) external view returns (uint256 longTokens, uint256 shortTokens);

  /**
   * @notice Generates a modified ancillary data that indicates the contract is being expired early.
   */
  function getEarlyExpirationAncillaryData() external view returns (bytes memory);

  /**
   * @notice Defines a special number that, if returned during an attempted early expiration, will cause the contract
   * to do nothing and not expire. This enables the OO (and DVM voters in the case of a dispute) to choose to keep
   * the contract running, thereby denying the early settlement request.
   */
  function ignoreEarlyExpirationPrice() external pure returns (int256);

  /**
   * @notice If the earlyExpirationTimestamp is != 0 then a previous early expiration OO request might still be in the
   * pending state. Check if the OO contains the ignore early price. If it does not contain this then the contract
   * was early expired correctly. Note that _getOraclePrice call will revert if the price request is still pending,
   * thereby reverting all upstream calls pre-settlement of the early expiration price request.
   */
  function isContractEarlyExpired() external returns (bool);
}
