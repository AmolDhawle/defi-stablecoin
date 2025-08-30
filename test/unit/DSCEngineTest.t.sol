// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {FailingERC20} from "../mocks/FailingERC20.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DSCEngine public engine;
    DecentralizedStableCoin public dsc;
    HelperConfig public helperConfig;

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;
    address public wethUsdPriceFeed;
    address public wbtcUsdPriceFeed;
    address public weth;
    address public wbtc;
    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;

    function setUp() external {
        deployer = new DeployDSC();
        (dsc, engine, helperConfig) = deployer.run();
        (wethUsdPriceFeed, wbtcUsdPriceFeed, weth, wbtc,) = helperConfig.activeNetworkConfig();
    }

    ////////////////////////
    /// Constructor test ///
    ////////////////////////

    function testRevertsIfTokenAddressesLengthDoesntMatchWithPricefeedsAddressesLength() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(wethUsdPriceFeed);
        priceFeedAddresses.push(wbtcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesAmountsDontMatch.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    ///////////////////
    /// Price Test  ///
    ///////////////////

    function testGetUsdValue() public view {
        uint256 ethAmount = 15e18;
        uint256 expectedUsdAmount = 30000e18;
        uint256 actualUsdAmount = engine.getUsdValue(weth, ethAmount);

        assertEq(expectedUsdAmount, actualUsdAmount);
    }

    function testGetTokenAmountFromUsd() public view {
        uint256 usdAmount = 100 ether;
        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = engine.getTokenAmountFromUsd(weth, usdAmount);

        assertEq(expectedWeth, actualWeth);
    }

    ///////////////////////////////
    /// Deposit Collateral Test ///
    ///////////////////////////////

    function testDepositCollateral() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.depositCollateral(weth, 0);

        vm.stopPrank();
    }

    function testDepositCollateralFailsIfTransferFromFails() public {
        FailingERC20 badToken = new FailingERC20();
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__TokenNotAllowed.selector, address(badToken)));
        engine.depositCollateral(address(badToken), AMOUNT_COLLATERAL);
    }

    function testRevertWithUnapprovedCollateral() public {
        ERC20Mock ranToken = new ERC20Mock("RAN", "RAN", USER, AMOUNT_COLLATERAL);

        vm.startPrank(USER);
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__TokenNotAllowed.selector, address(ranToken)));
        engine.depositCollateral(address(ranToken), AMOUNT_COLLATERAL);

        vm.stopPrank();
    }

    modifier depositedCollateral() {
        ERC20Mock(weth).mint(USER, AMOUNT_COLLATERAL);
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testCanDespositCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine.getAccountInformation(USER);

        uint256 expectedTotalAmountDscMinted = 0;
        uint256 expectedDepositAmount = engine.getTokenAmountFromUsd(weth, collateralValueInUsd);

        assertEq(totalDscMinted, expectedTotalAmountDscMinted);
        assertEq(expectedDepositAmount, AMOUNT_COLLATERAL);
    }

    ///////////////////////////////
    /// Mint DSC Tests          ///
    ///////////////////////////////

    function testMintDscFailsWithoutCollateral() public {
        vm.startPrank(USER);

        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, 0));

        engine.mintDsc(100 ether); // should fail because no collateral
        vm.stopPrank();
    }

    function testCanMintDscWithCollateral() public depositedCollateral {
        vm.startPrank(USER);
        engine.mintDsc(100 ether); // safe because user deposited 10 ETH collateral
        (uint256 totalDscMinted,) = engine.getAccountInformation(USER);
        assertEq(totalDscMinted, 100 ether);
        vm.stopPrank();
    }

    ///////////////////////////////
    /// Deposit + Mint Combined ///
    ///////////////////////////////

    function testDepositCollateralAndMintDsc() public {
        ERC20Mock(weth).mint(USER, AMOUNT_COLLATERAL);

        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        engine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, 100 ether);

        (uint256 totalDscMinted, uint256 collateralValueInUsd) = engine.getAccountInformation(USER);
        assertEq(totalDscMinted, 100 ether);
        assertGt(collateralValueInUsd, 0);
        vm.stopPrank();
    }

    function testMintDscRevertsIfZero() public depositedCollateral {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.mintDsc(0);
        vm.stopPrank();
    }

    function testDepositCollateralAndMintDscRevertsIfHealthFactorBreaks() public {
        ERC20Mock(weth).mint(USER, AMOUNT_COLLATERAL);

        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        uint256 expectedHealthFactor = 0.01 ether;
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, expectedHealthFactor));
        engine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, 1_000_000 ether);
        vm.stopPrank();
    }

    ///////////////////////////////
    /// Redeem Collateral Tests ///
    ///////////////////////////////

    function testCanRedeemCollateral() public depositedCollateral {
        vm.startPrank(USER);
        engine.redeemCollateral(weth, 5 ether); // redeem half
        uint256 balance = ERC20Mock(weth).balanceOf(USER);
        assertEq(balance, 5 ether);
        vm.stopPrank();
    }

    function testRedeemCollateralFailsIfMintedDebtNotBurned() public depositedCollateral {
        vm.startPrank(USER);
        engine.mintDsc(100 ether);
        vm.expectRevert();
        engine.redeemCollateral(weth, AMOUNT_COLLATERAL); // redeem all or most collateral

        vm.stopPrank();
    }

    function testRedeemCollateralFailsIfTransferFails() public depositedCollateral {
        // deploy mock token that always returns false on transfer
        FailingERC20 badToken = new FailingERC20();
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__TokenNotAllowed.selector, address(badToken)));
        engine.redeemCollateral(address(badToken), 1 ether);
    }

    function testRedeemCollateralForDsc() public depositedCollateral {
        vm.startPrank(USER);
        engine.mintDsc(100 ether);

        // burn DSC and redeem collateral
        dsc.approve(address(engine), 100 ether);
        engine.redeemCollateralForDsc(weth, 5 ether, 100 ether);

        assertEq(ERC20Mock(weth).balanceOf(USER), 5 ether);
        vm.stopPrank();
    }

    ///////////////////////////////
    /// Burn DSC Tests          ///
    ///////////////////////////////

    function testBurnDsc() public depositedCollateral {
        vm.startPrank(USER);
        engine.mintDsc(100 ether);
        dsc.approve(address(engine), 100 ether);

        engine.burnDsc(100 ether);
        (uint256 totalDscMinted,) = engine.getAccountInformation(USER);
        assertEq(totalDscMinted, 0);
        vm.stopPrank();
    }

    function testBurnDscFailsIfNoApproval() public depositedCollateral {
        vm.startPrank(USER);
        engine.mintDsc(100 ether);

        vm.expectRevert();
        engine.burnDsc(100 ether);

        vm.stopPrank();
    }

    ///////////////////////////////
    /// Liquidation Tests       ///
    ///////////////////////////////

    function testCantLiquidateHealthyUser() public {
        // Arrange: healthy user position
        ERC20Mock(weth).mint(USER, 10 ether);
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), 10 ether);
        engine.depositCollateral(weth, 10 ether); // $20k collateral
        engine.mintDsc(100 ether); // $100 debt → very healthy
        vm.stopPrank();

        // Give the liquidator 100 DSC by impersonating the owner (DSCEngine)
        address LIQ = makeAddr("liquidator");
        vm.startPrank(address(engine)); // DSCEngine owns DSC
        dsc.mint(LIQ, 100 ether);
        vm.stopPrank();

        // Liquidator approves and tries to liquidate a healthy user → should revert with HealthFactorOk
        vm.startPrank(LIQ);
        dsc.approve(address(engine), 100 ether);
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorOk.selector);
        engine.liquidate(weth, USER, 100 ether);
        vm.stopPrank();
    }

    ///////////////////////////////
    /// View Function Tests     ///
    ///////////////////////////////

    function testGetCollateralBalanceOfUser() public depositedCollateral {
        uint256 balance = engine.getCollateralBalanceOfUser(USER, weth);
        assertEq(balance, AMOUNT_COLLATERAL);
    }

    function testGetHealthFactor() public depositedCollateral {
        vm.startPrank(USER);
        engine.mintDsc(100 ether);
        vm.stopPrank();

        uint256 healthFactor = engine.getHealthFactor(USER);
        assertGt(healthFactor, 1e18); // still healthy
    }

    function testGetCollateralTokens() public view {
        address[] memory tokens = engine.getCollateralTokens();
        assertEq(tokens.length, 2); // weth + wbtc
    }

    function testRedeemCollateralRevertsIfItWouldBreakHealthFactor() public {
        // Arrange: user deposits 10 ETH and mints $9,900 DSC (HF ≈ 1.01)
        ERC20Mock(weth).mint(USER, 10 ether);
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), 10 ether);
        engine.depositCollateral(weth, 10 ether);
        engine.mintDsc(9900 ether);

        // Act/Assert: redeeming just over 0.1 ETH pushes HF < 1, so it must revert
        vm.expectRevert();
        engine.redeemCollateral(weth, 5 ether);

        vm.stopPrank();
    }

    function testCalculateHealthFactor() public view {
        uint256 totalDscMinted = 100 ether;
        uint256 result = engine.calculateHealthFactor(totalDscMinted, AMOUNT_COLLATERAL);
        assertGt(result, 0);
    }

    function testViewFunctions() public view {
        assertEq(engine.getPrecision(), 1e18);
        assertEq(engine.getAdditionalFeedPrecision(), 1e10);
        assertEq(engine.getLiquidationThreshold(), 50);
        assertEq(engine.getLiquidationBonus(), 10);
        assertEq(engine.getLiquidationPrecision(), 100);
        assertEq(engine.getMinHealthFactor(), 1e18);
        assertEq(engine.getDsc(), address(dsc));
        assertEq(engine.getCollateralTokenPriceFeed(weth), wethUsdPriceFeed);
    }
}
