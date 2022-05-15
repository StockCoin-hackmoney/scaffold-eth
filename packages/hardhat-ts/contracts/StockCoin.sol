// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

// import "./Babylon/interfaces/IStrategyFactory.sol";

contract StockCoin is ChainlinkClient, ConfirmedOwner {
  using Chainlink for Chainlink.Request;

  uint256 public stockPrice;
  string _jobId;
  uint256 private constant ORACLE_PAYMENT = (1 * LINK_DIVISIBILITY) / 10;
  address _oracle;
  address _gardenAddress;
  address _synthethicToken;

  constructor(
    address oracle,
    string memory jobId,
    address gardenAddress,
    address synthethicToken
  ) ConfirmedOwner(msg.sender) {
    setPublicChainlinkToken();
    _oracle = oracle;
    _jobId = jobId;
    _gardenAddress = gardenAddress;
    _synthethicToken = synthethicToken;

    // this strategy would convert all the liquidity to the synthetic token
    // IStrategyFactory.createStrategy(_name, _symbol, _strategist, _garden, _stratParams);
  }

  function executeStrategy() public {
    // execute strategy to get synthethic token
  }

  function expiredToken() public {
    // sell the synthetic token return the liquidity to the garden
  }

  function requestPriceStock(string memory _base) public {
    Chainlink.Request memory req = buildChainlinkRequest(stringToBytes32(_jobId), address(this), this.fullFillPriceStock.selector);
    req.add("base", _base);
    sendChainlinkRequestTo(_oracle, req, ORACLE_PAYMENT);
  }

  function fullFillPriceStock(bytes32 _requestId, uint256 _data) public recordChainlinkFulfillment(_requestId) {
    stockPrice = _data;
  }

  function cancelRequest(
    bytes32 _requestId,
    uint256 _payment,
    bytes4 _callbackFunctionId,
    uint256 _expiration
  ) public onlyOwner {
    cancelChainlinkRequest(_requestId, _payment, _callbackFunctionId, _expiration);
  }

  function stringToBytes32(string memory source) private pure returns (bytes32 result) {
    bytes memory tempEmptyStringTest = bytes(source);
    if (tempEmptyStringTest.length == 0) {
      return 0x0;
    }

    assembly {
      // solhint-disable-line no-inline-assembly
      result := mload(add(source, 32))
    }
  }

  function withdrawLink() public onlyOwner {
    LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
    require(link.transfer(msg.sender, link.balanceOf(address(this))), "Unable to transfer");
  }
}
