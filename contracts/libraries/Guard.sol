// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "./DepegSwapLib.sol";
import "./LvAssetLib.sol";

library Guard {
    using DepegSwapLibrary for DepegSwap;
    using LvAssetLibrary for LvAsset;

    /// @notice asset is expired
    error Expired();

    /// @notice asset is not expired. e.g trying to redeem before expiry
    error NotExpired();

    /// @notice asset is not initialized
    error Uinitialized();

    function _onlyNotExpired(DepegSwap storage ds) internal view {
        if (ds.isExpired()) {
            revert Expired();
        }
    }
    
    function _onlyNotExpired(LvAsset storage lv) internal view {
        if (lv.isExpired()) {
            revert Expired();
        }
    }

    function _onlyExpired(DepegSwap storage ds) internal view {
        if (!ds.isExpired()) {
            revert NotExpired();
        }
    }
    
    function _onlyExpired(LvAsset storage lv) internal view {
        if (!lv.isExpired()) {
            revert NotExpired();
        }
    }

    function _onlyInitialized(DepegSwap storage ds) internal view {
        if (!ds.isInitialized()) {
            revert Uinitialized();
        }
    }

    function _onlyInitialized(LvAsset storage lv) internal view {
        if (!lv.isInitialized()) {
            revert Uinitialized();
        }
    }

    function safeBeforeExpired(DepegSwap storage ds) internal view {
        _onlyInitialized(ds);
        _onlyNotExpired(ds);
    }
   
    function safeBeforeExpired(LvAsset storage lv) internal view {
        _onlyInitialized(lv);
        _onlyNotExpired(lv);
    }

    function safeAfterExpired(DepegSwap storage ds) internal view {
        _onlyInitialized(ds);
        _onlyExpired(ds);
    }
    
    function safeAfterExpired(LvAsset storage lv) internal view {
        _onlyInitialized(lv);
        _onlyExpired(lv);
    }
}
