// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./StockCoin.sol";

// import "./Babylon/interfaces/IBabController.sol";

contract FactoryStockCoin {
  // constructor(IBabController _controller) {
  //   require(address(_controller) != address(0), "invalid address");
  // }

  function deployStockCoin() public {
    // We probabily can try to change this from ERC20 TO ERC1155
    // address gardenAddress = IBabController.createGarden(
    //   _reserveAsset,
    //   _name,
    //   _symbol,
    //   _tokenURI,
    //   _seed,
    //   _gardenParams,
    //   _initialContribution,
    //   _publicGardenStrategistsStewards,
    //   _profitSharing
    // );

    address oracle;
    string memory jobId;
    address gardenAddress;

    StockCoin stockCoin = new StockCoin(oracle, jobId, gardenAddress);
  }
}
