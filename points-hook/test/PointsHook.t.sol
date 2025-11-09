// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

import {PoolManager} from "v4-core/PoolManager.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {PoolId} from "v4-core/types/PoolId.sol";

import {Hooks} from "v4-core/libraries/Hooks.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {SqrtPriceMath} from "v4-core/libraries/SqrtPriceMath.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";

import {ERC1155TokenReceiver} from "solmate/src/tokens/ERC1155.sol";

import "forge-std/console.sol";
import {PointsHook} from "../src/PointsHook.sol";

contract TestPointsHook is Test, Deployers, ERC1155TokenReceiver {

    MockERC20 token; // our token to use in the ETH-TOKEN pool

	// Native tokens are represented by address(0)
	Currency ethCurrency = Currency.wrap(address(0));
	Currency tokenCurrency;

    PointsHook hook;
 

    // SetUp() will be run at every test case 
	function setUp() public {
        // Deploy PoolManager and Router contracts
        deployFreshManagerAndRouters();

        // Deploy our TOKEN contract
        token = new MockERC20("Test Token", "TEST", 18);
        tokenCurrency = Currency.wrap(address(token));

        // Mint a bunch of TOKEN to ourselves and to address(1)
        token.mint(address(this), 1000 ether);
        token.mint(address(1), 1000 ether);

        // Deploy hook to an address that has the proper flags set
        uint160 flags = uint160(Hooks.AFTER_SWAP_FLAG);

        // deployCode(//location of the contract, // define the constructor arguments, //deploy contract to this address)
        deployCodeTo("PointsHook.sol", abi.encode(manager), address(flags));
        hook = PointsHook(address(flags));

        // Approve our TOKEN for spending on the swap router and modify liquidity router
        // These variables are coming from the `Deployers` contract
        token.approve(address(swapRouter), type(uint256).max);
        token.approve(address(modifyLiquidityRouter), type(uint256).max);


        // Initialize a pool
        (key, ) = initPool(
            ethCurrency, // Currency 0 = ETH (Address 0)
            tokenCurrency, // Currency 1 = TOKEN
            hook, // Hook Contract
            3000, // Swap Fees
            SQRT_PRICE_1_1 // Initial Sqrt(P) value = 1
        );

        // Add some liquidity to the pool
        uint160 sqrtPriceAtTickLower = TickMath.getSqrtPriceAtTick(-60);
        uint160 sqrtPriceAtTickUpper = TickMath.getSqrtPriceAtTick(60);

        uint256 ethToAdd = 0.003 ether;
        uint128 liquidityDelta = LiquidityAmounts.getLiquidityForAmount0(
            SQRT_PRICE_1_1,
            sqrtPriceAtTickUpper,
            ethToAdd
        );

        uint256 tokenToAdd = LiquidityAmounts.getAmount1ForLiquidity(
        sqrtPriceAtTickLower,
        SQRT_PRICE_1_1,
        liquidityDelta
    );

    modifyLiquidityRouter.modifyLiquidity{value: ethToAdd}(
        key,
        ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: int256(uint256(liquidityDelta)),
            salt: bytes32(0)
        }),
        ZERO_BYTES
    );



	}

    // Swap TOKEN for TOKEN -> no points

    // Test overflow amnt of tokens
    // SWAP TOKEN for ETH -> No POints
    function  test_swap_tokenForETH() public {

        // get the PoolId uint 
        uint256 poolIdUint = uint256(PoolId.unwrap(key.toId())); 

        uint256 pointsBalanceOriginal = hook.balanceOf(address(this), poolIdUint); 

        // How to confirm we have the right value ? 
        assertEq(pointsBalanceOriginal, 0, "points balance is not 0"); 

        bytes memory hookData = abi.encode(address(this)); 

        swapRouter.swap(
            key, 
            SwapParams({
                zeroForOne: false, 
                amountSpecified: -0.001 ether, 
                sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE - 1 
            }), 
            PoolSwapTest.TestSettings({
                takeClaims: false, 
                settleUsingBurn: false
            }), 
            hookData
        ); 

        uint256 pointsBalanceAfterSwap = hook.balanceOf(address(this), poolIdUint); 

        assertEq(pointsBalanceAfterSwap  , pointsBalanceOriginal,  "not equal");



    } 

    // Swap a number not divisible by 5 - > no points



    // Basic unit test for the swap function 
    function test_swap() public {

        // get the PoolId uint 
        uint256 poolIdUint = uint256(PoolId.unwrap(key.toId())); 

        uint256 pointsBalanceOriginal = hook.balanceOf(address(this), poolIdUint); 

        // How to confirm we have the right value ? 
        assertEq(pointsBalanceOriginal, 0, "points balance is not 0"); 

        bytes memory hookData = abi.encode(address(this)); 


        swapRouter.swap{value: 0.001 ether}(
            key, 
            SwapParams({
                zeroForOne: true, 
                amountSpecified: -0.001 ether, 
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1 
            }), 
            PoolSwapTest.TestSettings({
                takeClaims: false, 
                settleUsingBurn: false
            }), 
            hookData
        ); 

        uint256 pointsBalanceAfterSwap = hook.balanceOf(address(this), poolIdUint); 

        assertEq(pointsBalanceAfterSwap -  pointsBalanceOriginal, 0.001 ether * 20 / 100, "not equal");

        // Can also add other checks suchs as: 
        // Check amount ETH user spent 
        // Check pool manager now holds eth 

        // Add revert cases



    } 


    function testFuzz_swap(uint256 _amount, bool _zeroForOne, address _pointsRecipient) public {

        // to emsure we can convert the uint to an int
        // vm.assume(_amount < type(uint128).max) ;
        // vm.assume(_amount != 0 ) ;
        _amount = bound(_amount, 5, type(uint128).max); 
        vm.assume(_pointsRecipient != address(0)); 

        if (_zeroForOne) {
            // We need more ETH 
            deal(address(this), _amount);  
        } else {
            // We need more TOKEN
            deal(address(token), address(this), _amount) ;
            token.approve(address(swapRouter), _amount); 
        }


        uint256 poolIdUint = uint256(PoolId.unwrap(key.toId())); 
        uint256 pointsBalanceOriginal = hook.balanceOf(address(this), poolIdUint); 
        bytes memory hookData = abi.encode(address(this)); 


        swapRouter.swap{value: _zeroForOne ? _amount : 0}(
            key, 
            SwapParams({
                zeroForOne: _zeroForOne, 
                amountSpecified: -int256(_amount), 
                sqrtPriceLimitX96: _zeroForOne? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1 
            }), 
            PoolSwapTest.TestSettings({
                takeClaims: false, 
                settleUsingBurn: false
            }), 
            hookData
        ); 

        uint256 pointsBalanceAfterSwap = hook.balanceOf(address(this), poolIdUint); 


         if (_zeroForOne) {
            // We need more ETH 
            assertGt(pointsBalanceAfterSwap, pointsBalanceOriginal, "Points did not increase in value");
        } else {
            assertEq(pointsBalanceAfterSwap, pointsBalanceOriginal, "Points not equal"); 
        }

            

    }


}