const { expect } = require('chai');
const { ethers } = require('hardhat');
const addresses = require('./helpers/addresses');
const { getERC20, increaseTime } = require('./utils/test-helpers');
const { ADDRESS_ZERO, ONE_DAY_IN_SECONDS } = require('./helpers/constants');
const { impersonateAddress } = require('./helpers/rpc');
const { eth } = require('./helpers/helpers');
const { deployments } = require('hardhat');
const { assert } = require('console');
const { uniswap } = require('./helpers/addresses');
const { deploy } = deployments;
// const { takeSnapshot, restoreSnapshot } = require('lib/rpc');

const WETH = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';
const UniswapV3TradeIntegration = '0xc300FB5dE5384bcA63fb6eb3EfD9DB7dFd10325C';
const NFT_URI = 'https://babylon.mypinata.cloud/ipfs/QmcL826qNckBzEk2P11w4GQrrQFwGvR6XmUCuQgBX9ck1v';
const NFT_SEED = '504592746';

describe.only('UMA LongShort pair Integration', function () {
    let owner;
    let garden;
    let strategy;
    let controller;
    let keeper;
    let alice;
    let bob;

    before(async () => {
        [, keeper, alice, bob] = await ethers.getSigners();
        controller = await ethers.getContractAt('IBabController', '0xD4a5b5fcB561dAF3aDF86F8477555B92FBa43b5F');
        owner = await impersonateAddress('0x97FcC2Ae862D03143b393e9fA73A32b563d57A6e');
        await controller.connect(owner).addKeeper(keeper.address);

        // Creates a garden with custom integrations enabled
        const contribution = eth(1);
        await controller.connect(alice).createGarden(
            WETH,
            'Fountain',
            'FTN',
            NFT_URI,
            NFT_SEED,
            [
                eth(100), // Max Deposit Limit
                1, // Min Liquidity Asset | ie: Uniswap Volume
                1, // Deposit Hardlock | 1 second
                eth(0.1), // Min Contribution
                ONE_DAY_IN_SECONDS, // Strategy Cooldown Period
                eth(0.1), // Min Voter Quorum | 10%
                ONE_DAY_IN_SECONDS * 3, // Min Strategy Duration
                ONE_DAY_IN_SECONDS * 365, // Max Strategy Duration
                1, // Min number of voters
                eth(), // Decay rate of price per share
                eth(), // Base slippage for price per share
                1, // Can mint NFT after 1 sec of being a member
                1 // Whether or not the garden has custom integrations enabled
            ],
            contribution,
            [true, true, true], // publicGardenStrategistsStewards
            [0, 0, 0], // Profit splits. Use defaults
            {
                value: contribution,
            },
        );

        const gardens = await controller.getGardens();
        // console.log(`Garden created at ${gardens[0]}`);
        garden = await ethers.getContractAt('IGarden', gardens.slice(-1)[0]);
        // Alternatively you can use mainnet Test WETH garden that has custom integrations enabled
        // garden = await ethers.getContractAt('IGarden', '0x2c4Beb32f0c80309876F028694B4633509e942D4');


    });

    beforeEach(async () => { });

    afterEach(async () => { });

    it('Can deploy strategy with UMA LS pair long side', async () => {


        const longShortPair = await ethers.getContractAt("ILongShortPair", "0x94E653AF059550657e839a5DFCCA5a17fD17EFdf");
        const longTokenAddress = await longShortPair.longToken();
        const longToken = await ethers.getContractAt("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20", longTokenAddress);
        const shortTokenAddress = await longShortPair.shortToken();
        const shortToken = await ethers.getContractAt("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20", shortTokenAddress);


        const longShortPairETHSEP = "0x94E653AF059550657e839a5DFCCA5a17fD17EFdf";

        // We deploy the custom yearn integration. Change with your own integration when ready
        const customIntegration = await deploy('CustomIntegrationUmaLong', {
            from: alice.address,
            args: [controller.address],
        });

        await garden.connect(alice).addStrategy(
            'Execute my custom integration',
            '💎',
            [
                eth(10), // maxCapitalRequested: eth(10),
                eth(0.1), // stake: eth(0.1),
                ONE_DAY_IN_SECONDS * 30, // strategyDuration: ONE_DAY_IN_SECONDS * 30,
                eth(0.05), // expectedReturn: eth(0.05),
                eth(0.1), // maxAllocationPercentage: eth(0.1),
                eth(0.05), // maxGasFeePercentage: eth(0.05),
                eth(0.09), // maxTradeSlippagePercentage: eth(0.09),
            ],
            [5], // _opTypes
            [customIntegration.address], // _opIntegrations
            new ethers.utils.AbiCoder().encode(
                ['address', 'uint256'],
                // long shor pair
                [longShortPairETHSEP, 0] // integration params. We pass USDT vault
            ), // _opEncodedDatas
        );


        const strategies = await garden.getStrategies();
        customStrategy = await ethers.getContractAt('IStrategy', strategies[0]);

        await garden.connect(alice).deposit(eth(1), 0, alice.address, ADDRESS_ZERO, {
            value: eth(1),
        });


        const balance = await garden.balanceOf(alice.getAddress());

        // Vote Strategy
        await customStrategy.connect(keeper).resolveVoting([alice.address], [balance], 0);



        // Execute strategy
        await increaseTime(ONE_DAY_IN_SECONDS);
        await customStrategy.connect(keeper).executeStrategy(eth(1), 0);

        const balanceShortToken = await shortToken.balanceOf(customStrategy.address);
        const balanceLongToken = await longToken.balanceOf(customStrategy.address);


        // Right now the strategy cant sell short/long token because there is not enough liquidity on mainnet
        // So both values would be the same


        expect(balanceShortToken).equals(balanceLongToken);


        // Finalizing the strategy will fail because tokens have not expired yet and dont expire automatically
        await increaseTime(ONE_DAY_IN_SECONDS * 30);
        await expect(customStrategy.connect(keeper).finalizeStrategy(0, '', 0)).to.be.revertedWith("Cannot exit before the token is expired and price has been received!");



        console.log("balanceShortToken", balanceShortToken);
        console.log("balanceLongToken", balanceLongToken);


    });

    it('Can deploy strategy with UMA LS pair short side', async () => {


        const longShortPair = await ethers.getContractAt("ILongShortPair", "0x94E653AF059550657e839a5DFCCA5a17fD17EFdf");
        const longTokenAddress = await longShortPair.longToken();
        const longToken = await ethers.getContractAt("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20", longTokenAddress);
        const shortTokenAddress = await longShortPair.shortToken();
        const shortToken = await ethers.getContractAt("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20", shortTokenAddress);

        const longShortPairETHSEP = "0x94E653AF059550657e839a5DFCCA5a17fD17EFdf";

        // We deploy the custom yearn integration. Change with your own integration when ready
        const customIntegration = await deploy('CustomIntegrationUmaShort', {
            from: alice.address,
            args: [controller.address],
        });

        await garden.connect(alice).addStrategy(
            'Execute my custom integration',
            '💎',
            [
                eth(10), // maxCapitalRequested: eth(10),
                eth(0.1), // stake: eth(0.1),
                ONE_DAY_IN_SECONDS * 30, // strategyDuration: ONE_DAY_IN_SECONDS * 30,
                eth(0.05), // expectedReturn: eth(0.05),
                eth(0.1), // maxAllocationPercentage: eth(0.1),
                eth(0.05), // maxGasFeePercentage: eth(0.05),
                eth(0.09), // maxTradeSlippagePercentage: eth(0.09),
            ],
            [5], // _opTypes
            [customIntegration.address], // _opIntegrations
            new ethers.utils.AbiCoder().encode(
                ['address', 'uint256'],
                // long shor pair
                [longShortPairETHSEP, 0] // integration params. We pass USDT vault
            ), // _opEncodedDatas
        );


        const strategies = await garden.getStrategies();
        customStrategy = await ethers.getContractAt('IStrategy', strategies[1]);

        await garden.connect(alice).deposit(eth(1), 0, alice.address, ADDRESS_ZERO, {
            value: eth(1),
        });


        const balance = await garden.balanceOf(alice.getAddress());

        // Vote Strategy
        await customStrategy.connect(keeper).resolveVoting([alice.address], [balance], 0);



        // Execute strategy
        await increaseTime(ONE_DAY_IN_SECONDS);
        await customStrategy.connect(keeper).executeStrategy(eth(1), 0);

        const balanceShortToken = await shortToken.balanceOf(customStrategy.address);
        const balanceLongToken = await longToken.balanceOf(customStrategy.address);

        // Right now the strategy cant sell short/long token because there is not enough liquidity on mainnet
        // So both values would be the same


        expect(balanceShortToken).equals(balanceLongToken);


        // Finalizing the strategy will fail because tokens have not expired yet and dont expire automatically
        await increaseTime(ONE_DAY_IN_SECONDS * 30);
        await expect(customStrategy.connect(keeper).finalizeStrategy(0, '', 0)).to.be.revertedWith("Cannot exit before the token is expired and price has been received!");



        console.log("balanceShortToken", balanceShortToken);
        console.log("balanceLongToken", balanceLongToken);


    });
    it.skip('send usdc get long token', async () => {

        const USDC = await ethers.getContractAt("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20", "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48");
        const usdcholder = await impersonateAddress("0x47ac0fb4f2d84898e4d9e7b4dab3c24507a6d503");
        const longShortPair = await ethers.getContractAt("ILongShortPair", "0x94E653AF059550657e839a5DFCCA5a17fD17EFdf");

        await USDC.connect(usdcholder).approve(longShortPair.address, eth(4000));
        await longShortPair.connect(usdcholder).create(100);

        const longToken = await ethers.getContractAt("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20", "0x285e6252e2649a4dbf1244c504e0e86c92b745e7");
        const amount = await longToken.balanceOf(usdcholder.address);


        console.log(amount);
    });
    it.skip('can swap shorttoken for usdc', async () => {

        const USDC = await ethers.getContractAt("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20", "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48");
        const usdcholder = await impersonateAddress("0x47ac0fb4f2d84898e4d9e7b4dab3c24507a6d503");
        const longShortPair = await ethers.getContractAt("ILongShortPair", "0x94E653AF059550657e839a5DFCCA5a17fD17EFdf");


        await USDC.connect(usdcholder).approve(longShortPair.address, eth(4000));
        await longShortPair.connect(usdcholder).create(100);

        const shortTokenAddress = await longShortPair.shortToken();
        const longToken = await ethers.getContractAt("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20", shortTokenAddress);
        const amount = await longToken.balanceOf(usdcholder.address);
        const uniswapContract = await ethers.getContractAt("IUniswapV2Router", "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D");
        const blockNumber = await ethers.provider.getBlockNumber();
        const blockBefore = await ethers.provider.getBlock(blockNumber);

        console.log(uniswapContract.interface.getSighash("swapExactTokensForTokens"))

        await longToken.connect(usdcholder).approve(uniswapContract.address, eth(4000));
        await uniswapContract.connect(usdcholder).swapExactTokensForTokens(amount, 0, [shortTokenAddress, USDC.address], usdcholder.address, blockBefore.timestamp + 10)

        const amount2 = await longToken.balanceOf(usdcholder.address);
        console.log("final long token", amount2);
    });

    it.skip('can add liquidity invETHDOM/USDC', async () => {

        const blockNumber = await ethers.provider.getBlockNumber();
        const blockBefore = await ethers.provider.getBlock(blockNumber);


        const USDC = await ethers.getContractAt("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20", "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48");
        const usdcholder = await impersonateAddress("0x47ac0fb4f2d84898e4d9e7b4dab3c24507a6d503");
        const uniswapContract = await ethers.getContractAt("IUniswapV2Router", "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D");
        const uniswapPool = await ethers.getContractAt("IUniswapV2PairB", "0x1b81da9182f26cd4ab565977f1c176e92bf0769d");
        const longShortPair = await ethers.getContractAt("ILongShortPair", "0x94E653AF059550657e839a5DFCCA5a17fD17EFdf");
        const shortTokenAddress = await longShortPair.shortToken();
        const shortToken = await ethers.getContractAt("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20", shortTokenAddress);

        await USDC.connect(usdcholder).approve(longShortPair.address, eth(400000000000000000));
        await longShortPair.connect(usdcholder).create(100000000);
        await shortToken.connect(usdcholder).approve(uniswapContract.address, eth(400000000000000000));
        await USDC.connect(usdcholder).approve(uniswapContract.address, eth(400000000000000000));


        console.log("pre", await uniswapPool.getReserves());

        await uniswapContract.connect(usdcholder).addLiquidity(USDC.address, shortTokenAddress, 4000000000, 100000000, 0, 0, usdcholder.address, blockBefore.timestamp + 10)


        console.log("post", await uniswapPool.getReserves());
    });
});
