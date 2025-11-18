// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {CurrencySettler} from "@uniswap/v4-core/test/utils/CurrencySettler.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary,  toBeforeSwapDelta} from "v4-core/types/BeforeSwapDelta.sol";
import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {ModifyLiquidityParams, SwapParams} from "v4-core/types/PoolOperation.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";

contract GasPriceFeesHook is BaseHook {
    using LPFeeLibrary for uint24; 
    error MustUseDynamicFee(); 
    // average gas price 
    uint128 public movingAverageGasPrice ;
    // number of transactions recorded
    uint104 public movingAverageGasPriceCount;  

    // Default fee of the pool (0.5% fees)
    uint24 public constant BASE_FEE = 5000; 

    constructor(IPoolManager poolManager) BaseHook(poolManager){
        updateMovingAverage(); 
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: true,
            afterInitialize: false,
            beforeAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterAddLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }
    function _beforeInitialize(address, PoolKey calldata key, uint160) internal pure override returns (bytes4){
        //validate pool keys being added 
        // Does the poolkey support dynamic fees ? 
        if (!key.fee.isDynamicFee()) {
            revert MustUseDynamicFee(); 
        }

        return this.beforeInitialize.selector; 
    }

    function _beforeSwap(address, PoolKey calldata key , SwapParams calldata, bytes calldata) internal override returns (bytes4, BeforeSwapDelta, uint24){
        // deteremine the fee paid for the swap 
         uint24 fees = getFee();  

        // update the swap fee in the PoolManager 
        uint24 feeWithFlag = fees | LPFeeLibrary.OVERRIDE_FEE_FLAG; 

        return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, feeWithFlag); 
    } 


    // Get the current gas price 
    // compare the current gas price to our moving average 
    // Calculate the amount of fees that should be charged (based on current gas price <> moving average)
    function getFee() internal returns (uint24) {
        uint128 gasPrice = uint128(tx.gasprice); 

        // Gas Price > moving average -> lower the swap fees
        if (gasPrice >  (movingAverageGasPrice * 11) / 10) {
            // 10% more 
            return BASE_FEE / 2 ;

        } 

        // Gas Price < moving average -> increase the swap fees
        if (gasPrice < (movingAverageGasPrice * 9) / 10 ){
            return BASE_FEE * 2 ; 
        } 

        // Gas price within moving average threshold 
        return BASE_FEE; 

    }

    // update moving average gas price
    function updateMovingAverage() internal {
        uint128 gasPrice = uint128(tx.gasprice); // get current gas price
         // Update the moving average 
         // (OLD_AVERAGE * #transactions tracked + current price ) / #tracsactions tracked + 1
         movingAverageGasPrice = (movingAverageGasPrice * movingAverageGasPriceCount + gasPrice) / 
         (movingAverageGasPriceCount + 1) ; 

         movingAverageGasPriceCount = movingAverageGasPriceCount + 1 ; 
    } 

    function _afterSwap(address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        BalanceDelta ,
        bytes calldata hookData) internal override returns (bytes4, int128) { 
        // update internal moving average gas price 
        updateMovingAverage(); 
        return (this.afterSwap.selector , 0 ) ;
    }

} 
