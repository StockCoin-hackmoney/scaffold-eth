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
    let controller;
    let keeper;
    let alice;

    // 
    let longTokenAddress;
    let longToken;
    let shortTokenAddress;
    let shortToken;
    let longShortPairETHSEPAddress;
    let longShortPairETHSEP;

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

        // Long short Pair for ETH SEP integration 

        longShortPairETHSEPAddress = "0x94E653AF059550657e839a5DFCCA5a17fD17EFdf";
        longShortPairETHSEP = await ethers.getContractAt("ILongShortPair", longShortPairETHSEPAddress);
        longTokenAddress = await longShortPairETHSEP.longToken();
        longToken = await ethers.getContractAt("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20", longTokenAddress);
        shortTokenAddress = await longShortPairETHSEP.shortToken();
        shortToken = await ethers.getContractAt("@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20", shortTokenAddress);

    });

    beforeEach(async () => { });

    afterEach(async () => { });

    it('Can deploy strategy with UMA LS pair long side', async () => {

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
                [longShortPairETHSEPAddress, 0] // integration params. We pass USDT vault
            ), // _opEncodedDatas
        );
    });


    it('Can get correct amount of long tokens and short tokens after executing strategy long side', async () => {

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


        // collateralPerPair = ratio of tokens created by quantity of usdc
        const collateralPerPair = await longShortPairETHSEP.collateralPerPair();

        // Calculating amount of USDC by 1 ether

        const AggregatorV3ETHUSDC = await ethers.getContractAt("AggregatorV3Interface", "0x986b5E1e1755e3C2440e960477f25201B0a8bbD4");
        const latestRoundData = await AggregatorV3ETHUSDC.latestRoundData();
        const ethPerUSDC = ethers.utils.formatEther(latestRoundData['answer'])
        const totalUSDC = 1 / ethPerUSDC;


        const amountOfLSTokens = totalUSDC / ethers.utils.formatEther(collateralPerPair);
        const balanceShortToken = await longToken.balanceOf(customStrategy.address);

        // uma tokens only have 6 decimals 
        const parsedbalanceShortToken = parseInt(balanceShortToken['_hex'], 16) / 1000000;

        // delta of 0.1 for eth price change
        expect(parsedbalanceShortToken).closeTo(amountOfLSTokens, 0.1)

        // short token will be 0

        // expect(await shortToken.balanceOf(customStrategy.address)).to.be.equal(0);
    });

    it('Can not finalize the strategy until the token is expired long side', async () => {

        // Finalizing the strategy will fail because tokens have not expired yet and dont expire automatically
        await increaseTime(ONE_DAY_IN_SECONDS * 30);
        await expect(customStrategy.connect(keeper).finalizeStrategy(0, '', 0)).to.be.revertedWith("Cannot exit before the token is expired and price has been received!");

    });


    it('Can deploy strategy with UMA LS pair short side', async () => {

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
                [longShortPairETHSEPAddress, 0] // integration params. We pass USDT vault
            ), // _opEncodedDatas
        );
    });

    it('Can get correct amount of long tokens and short tokens after executing strategy short side', async () => {

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

        // collateralPerPair = ratio of tokens created by quantity of usdc
        const collateralPerPair = await longShortPairETHSEP.collateralPerPair();

        // Calculating amount of USDC by 1 ether

        const AggregatorV3ETHUSDC = await ethers.getContractAt("AggregatorV3Interface", "0x986b5E1e1755e3C2440e960477f25201B0a8bbD4");
        const latestRoundData = await AggregatorV3ETHUSDC.latestRoundData();
        const ethPerUSDC = ethers.utils.formatEther(latestRoundData['answer'])
        const totalUSDC = 1 / ethPerUSDC;


        const amountOfLSTokens = totalUSDC / ethers.utils.formatEther(collateralPerPair);
        const balanceShortToken = await shortToken.balanceOf(customStrategy.address);

        // uma tokens only have 6 decimals 
        const parsedBalanceShortToken = parseInt(balanceShortToken['_hex'], 16) / 1000000;

        // delta of 0.1 for eth price change
        expect(parsedBalanceShortToken).closeTo(amountOfLSTokens, 0.1)

        // long token will be 0 
        // expect(await longToken.balanceOf(customStrategy.address)).to.be.equal(0);

    });

    it('Can not finalize the strategy until the token is expired short side', async () => {

        // Finalizing the strategy will fail because tokens have not expired yet and dont expire automatically
        await increaseTime(ONE_DAY_IN_SECONDS * 30);
        await expect(customStrategy.connect(keeper).finalizeStrategy(0, '', 0)).to.be.revertedWith("Cannot exit before the token is expired and price has been received!");

    });
});
