pragma solidity ^0.8.24;

import {TestERC20} from "./TestERC20.t.sol";

import "../../../contracts/core/CorkConfig.sol";

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {ICorkHook} from "Cork-Hook/interfaces/ICorkHook.sol";
import {MarketSnapshot} from "Cork-Hook/lib/MarketSnapshot.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "v4-periphery/lib/v4-core/src/types/PoolKey.sol";
import {TestAsset} from "./TestAsset.k.sol";
import {TestFlashSwapRouter}     from "test/forge/kontrol/TestFlashSwapRouter.k.sol";

import "forge-std/Test.sol";
import {KontrolTest} from "./KontrolTest.k.sol";

/// @title TestCorkHook Contract, used for testing CorkHook contract, mostly here for getter functions
contract TestCorkHook is ICorkHook, Test, KontrolTest {
    address lpBase;
    address poolManager;

    uint256 public raAdded;
    uint256 public ctAdded;
    uint256 public lpMinted;

    uint256 private _amountOutMin;

    bool private _isFlashSwap;
    uint256 private _amountIn;
    address private _flashSwapRouter;

    struct CallbackData {
        bool buyDs;
        address caller;
        // CT or RA amount borrowed
        uint256 borrowed;
        // DS or RA amount provided
        uint256 provided;
        // DS/RA amount attributed to user
        uint256 attributed;
        Id reserveId;
        uint256 dsId;
    }

    constructor(address _poolManager, address _lpBase) {
        kevm.symbolicStorage(address(this));

        bytes32 initializeSlot = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;

        vm.store(address(this), initializeSlot, bytes32(0));

        lpBase = _lpBase;
        poolManager = _poolManager;
        raAdded = 0;
        ctAdded = 0;
        lpMinted = 0;

        _flashSwapRouter = address(0);
        _isFlashSwap = false;
        _amountIn = 0;

        /*
        TODO: update:

        // _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        bytes32 hasAdminRoleSlot = keccak256(abi.encode(msg.sender, keccak256(abi.encode(DEFAULT_ADMIN_ROLE, uint256(0)))));
        vm.store(address(this), hasAdminRoleSlot, bytes32(uint256(1)));
        
        bytes32 hasManagerRoleSlot = keccak256(abi.encode(msg.sender, keccak256(abi.encode(MANAGER_ROLE, uint256(0)))));
        vm.store(address(this), hasManagerRoleSlot, bytes32(0));
        */
    }

    function setAmountIn(uint256 amountIn) public {
        _amountIn = amountIn;
    }

    function setAmountOutMin(uint256 amountOutMin) public {
        _amountOutMin = amountOutMin;
    }

    function isFlashSwap(bool isFlashSwapExecuted) public {
        _isFlashSwap = isFlashSwapExecuted;
    }

    function setFlashSwapRouter(address flashSwapRouter) external {
        _flashSwapRouter = flashSwapRouter;
    }

    function addLiquidity(
        address ra,
        address ct,
        uint256 raAmount,
        uint256 ctAmount,
        uint256 amountRamin,
        uint256 amountCtmin,
        uint256 deadline
    ) external returns (uint256 amountRa, uint256 amountCt, uint256 mintedLp) {
        (amountRa, amountCt, mintedLp)  = 
            (kevm.freshUInt(32, "amountRa"), kevm.freshUInt(32, "amountCt"), freshUInt256Bounded("mintedLp"));

        vm.assume(amountRa <= raAmount);
        vm.assume(amountCt <= ctAmount);
        vm.assume(mintedLp <= IERC20(lpBase).totalSupply());

        SafeERC20.safeTransferFrom(IERC20(ct), msg.sender, address(this), amountCt);

        SafeERC20.safeTransferFrom(IERC20(ra), msg.sender, address(this), amountRa);
        
        // Mint LP
        TestERC20(lpBase).mint(msg.sender, mintedLp);

        // Save the variables
        raAdded = amountRa;
        ctAdded = amountCt;
        lpMinted = mintedLp;
    }

    function swap(address ra, address ct, uint256 amountRaOut, uint256 amountCtOut, bytes calldata data)
        external
        returns (uint256 amountIn) {
            if (_isFlashSwap) {
                CallbackData memory callbackData = abi.decode(data, (CallbackData));

                if (callbackData.buyDs) {
                    uint256 actualRepaymentAmount = freshUInt256Bounded("actualRepaymentAmount");

                    // hook has enough RA tokens for the flash loan
                    vm.assume(amountRaOut <= TestERC20(ra).balanceOf(address(this)));
                    // no overflow on the flash loan transfer of RA to the router
                    unchecked {
                        vm.assume(amountRaOut + TestERC20(ra).balanceOf(_flashSwapRouter) >= amountRaOut);
                    }

                    TestERC20(ra).transfer(_flashSwapRouter, amountRaOut);

                    // mock for the flashSwapRouter callback
                    TestFlashSwapRouter(_flashSwapRouter).CorkCallMockRaToDs(callbackData.reserveId, ra, address(this), callbackData.caller, actualRepaymentAmount, callbackData.attributed, amountRaOut, callbackData.provided, callbackData.dsId);            
                    return actualRepaymentAmount;
                } else {
                    amountIn = _amountIn;

                    // hook has enough CT tokens for the flash loan
                    vm.assume(amountCtOut <= TestAsset(ct).balanceOf(address(this)));
                    // no overflow on the flash loan transfer of CT to the router
                    unchecked {
                        vm.assume(amountCtOut + TestAsset(ct).balanceOf(_flashSwapRouter) >= amountCtOut);
                    }

                    TestAsset(ct).transfer(_flashSwapRouter, amountCtOut);

                    // mock for the flashSwapRouter callback
                    TestFlashSwapRouter(_flashSwapRouter).CorkCallMockDsToRa(callbackData.reserveId, ra, address(this), callbackData.caller, amountIn, callbackData.attributed, amountCtOut, callbackData.dsId);
                    return amountIn;
                }
            } else {
                return freshUInt256Bounded();
            }
        }

    function removeLiquidity(
        address ra,
        address ct,
        uint256 liquidityAmount,
        uint256 amountRamin,
        uint256 amountCtmin,
        uint256 deadline
    ) external returns (uint256 amountRa, uint256 amountCt) {
        amountRa = freshUInt256Bounded("amountRa");
        amountCt = freshUInt256Bounded("amountCt");

        vm.assume(amountRa >= _amountOutMin);
        vm.assume(amountRa <= IERC20(ra).balanceOf(address(this)));
        vm.assume(amountCt <= IERC20(ct).balanceOf(address(this)));

        IERC20(ct).transfer(msg.sender, amountCt);
        IERC20(ra).transfer(msg.sender, amountRa);
        TestERC20(lpBase).burnFrom(msg.sender, liquidityAmount);
    }

    function getLiquidityToken(address ra, address ct) external view returns (address) {
        // WARNING: It returns lpBase for the purpose of the current tests is enough since lpbase is symbolic
        return lpBase;
    }

    function getReserves(address ra, address ct) external view returns (uint256, uint256) {
        return (freshUInt256Bounded(), freshUInt256Bounded());
    }

    function getFee(address ra, address ct)
        external
        view
        returns (uint256 baseFeePercentage, uint256 actualFeePercentage) {
            // TODO: Update constraints on fees
            return (freshUInt256Bounded(), freshUInt256Bounded());
        }

    function getAmountIn(address ra, address ct, bool zeroForOne, uint256 amountOut)
        external
        view
        returns (uint256 amountIn) {
            if (_isFlashSwap) {
                return _amountIn;
            } else {
                return freshUInt256Bounded();
            }
        }

    function getAmountOut(address ra, address ct, bool zeroForOne, uint256 amountIn)
        external
        view
        returns (uint256 amountOut){
            return freshUInt256Bounded();
        }

    function getPoolManager() external view returns (address) {
        // TODO: UPdate it once contract has a poolManager
        return poolManager;
    }

    function getForwarder() external view returns (address) {
         // TODO: UPdate it once contract has a forwarder
        return freshAddress();
    }

    function getMarketSnapshot(address ra, address ct) external view returns (MarketSnapshot memory) {
        // TODO: Make it more symbolic later
        MarketSnapshot memory snapshot = MarketSnapshot(address(0), address(0), 0, 0, 0, 0, lpBase);
        /* TODO: to adjust to the recent CorkHook version, it should be updated e.g., as follows: 
        MarketSnapshot memory snapshot = MarketSnapshot(address(0), address(0), 0, 0, 0, 0, lpBase, 0, 0, 0);
        */
        return snapshot;
    }

    function getPoolKey(address ra, address ct) external view returns (PoolKey memory) {

    }

}