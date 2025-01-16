pragma solidity ^0.8.24;

import {ModuleCoreTest} from "./ModuleCoreTest.k.sol";

import {Id, Pair}        from "../../../contracts/libraries/Pair.sol";
import {IDsFlashSwapCore} from "../../../contracts/interfaces/IDsFlashSwapRouter.sol";
import {SwapperMathLibrary} from "../../../contracts/libraries/DsSwapperMathLib.sol";
import {AssetPair} from "../../../contracts/libraries/DsFlashSwap.sol";

import {Asset}     from "../../../contracts/core/assets/Asset.sol";
import {TestAsset}     from "./TestAsset.k.sol";
import {TestERC20} from "./TestERC20.t.sol";

import {KontrolTest} from "./KontrolTest.k.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/* An alternative approach to use `vm.mockCall` is to deploy a mock contract and call the function on it
 using the `vm.mockFunction` cheatcode */
contract ModuleCoreMock {
    function lvAcceptRolloverProfit(Id id, uint256 amount) external {}    
}

contract RouterTest is ModuleCoreTest {
    ProofState private preState;
    ProofState private posState;

    struct ProofState {
        uint256 moduleCoreRaBalance;
        uint256 sellerRaBalance;
        uint256 sellerDsBalance;
        uint256 routerRaBalance;
        uint256 routerDsBalance;
        uint256 moduleCorePsmPoolArchiveRolloverProfit;
        uint256 moduleCorePsmReserve;
        uint256 moduleCoreLvReserve;
    }

    function setUp() public override {
        super.setUp();

        uint256 hyia = freshUInt256Bounded("hiya");
        setSymbolicState(2, hyia);
    }

    function _assumeSwapRaForDsPreState(address seller, uint256 amount) internal {
        Pair memory pair = moduleCore.getPairInfo(id);
        (address ds, address ct) = moduleCore.getDsCtPair(id);
        uint256 dsId = moduleCore.getDsId(id);

        address ra = pair.ra;

        // Assume `amount` is positive
        vm.assume(amount > 0);

        // Seller has symbolic amount of DS and RA
        TestERC20(ra).setSymbolicBalanceOf(seller, "sellerRaBalance");        
        TestERC20(ra).setSymbolicAllowance(seller, address(flashSwapRouter), "sellerRouterRaAllowance");
        TestAsset(ds).setSymbolicBalanceOf(seller, "sellerDsBalance");

        uint256 sellerBalanceRa = TestERC20(ra).balanceOf(seller);

        // Seller has a sufficient balance of RA to transfer `amount`
        vm.assume(sellerBalanceRa >= amount);
        // Seller has given a sufficient allowance of RA to the router
        uint256 allowance = TestERC20(ra).allowance(seller, address(flashSwapRouter));
        vm.assume(allowance >= amount);

        // FlashSwapRouter has symbolic amount of DS and RA
        TestAsset(ds).setSymbolicBalanceOf(address(flashSwapRouter), "routerDsBalance");
        TestERC20(ra).setSymbolicBalanceOf(address(flashSwapRouter), "routerRaBalance");

        uint256 routerBalanceRa = TestERC20(ra).balanceOf(address(flashSwapRouter));

        // Assuming that no overflow occurs on transfer to the router
        vm.assume(routerBalanceRa <= type(uint256).max - amount);

        // Assuming that hiya is not 0 to enable rollover sale, prevent branching on its values,
        // and that it is sufficiently small to not overflow
        vm.assume(flashSwapRouter.getHiya(id) > 0);
        vm.assume(flashSwapRouter.getHiyeCumulated(id) > 0);
        vm.assume(flashSwapRouter.getHiyeCumulated(id) <= 1e8);
        vm.assume(flashSwapRouter.getVhiyaCumulated(id) <= 1e8);
    }

    function _stateSnapshotSwap(ProofState storage state, address seller) internal {
        Pair memory pair = moduleCore.getPairInfo(id);
        (address ds, address ct) = moduleCore.getDsCtPair(id);
        uint256 dsId = moduleCore.getDsId(id);

        state.moduleCoreRaBalance = IERC20(pair.ra).balanceOf(address(moduleCore));
        state.routerRaBalance = IERC20(pair.ra).balanceOf(address(flashSwapRouter));
        state.routerDsBalance = TestAsset(ds).balanceOf(address(flashSwapRouter));
        state.sellerRaBalance = IERC20(pair.ra).balanceOf(seller);
        state.sellerDsBalance = TestAsset(ds).balanceOf(seller);
        state.moduleCorePsmPoolArchiveRolloverProfit = moduleCore.getPsmPoolArchiveRolloverProfit(id, dsId);
        state.moduleCorePsmReserve = flashSwapRouter.getAssetPair(id, dsId).psmReserve;
        state.moduleCoreLvReserve = flashSwapRouter.getAssetPair(id, dsId).lvReserve;
    }

    function _mockSwapRaForDsRouterCalls(uint256 amount, uint256 amountOutMin) internal returns (uint256 psmProfit, uint256 lvProfit, uint256 psmReserveUsed, uint256 lvReserveUsed) {
        // Mocking the `lvAcceptRolloverProfit` function; depositing into LV is covered by a separate proof
        ModuleCoreMock mock = new ModuleCoreMock();
        vm.mockFunction(
            address(moduleCore), address(mock), abi.encodeWithSelector(ModuleCoreMock.lvAcceptRolloverProfit.selector)
        );

        // Mocking the result of hiya calculation with an arbitrary concrete value, assuming it doesn't overflow
        vm.mockCall(address(SwapperMathLibrary), abi.encodeWithSelector(SwapperMathLibrary.calcHIYAaccumulated.selector), abi.encode(1));
        vm.mockCall(address(SwapperMathLibrary), abi.encodeWithSelector(SwapperMathLibrary.calcVHIYAaccumulated.selector), abi.encode(1));
 
        uint256 dsReceived;
        uint256 raLeft;
         // Mocking the call to `calculateRolloverSale`
        (lvProfit, psmProfit, raLeft, dsReceived, lvReserveUsed, psmReserveUsed) = (
            freshUInt256Bounded("lvProfit"),
            freshUInt256Bounded("psmProfit"),
            freshUInt256Bounded("raLeft"),
            freshUInt256Bounded("dsReceived"),
            freshUInt256Bounded("lvReserveUsed"),
            freshUInt256Bounded("psmReserveUsed")
        );

        // Returning after rollover sale as the swap has been completed
        vm.assume(raLeft == 0);

        vm.mockCall(address(SwapperMathLibrary), abi.encodeWithSelector(SwapperMathLibrary.calculateRolloverSale.selector), abi.encode(lvProfit, psmProfit, raLeft, dsReceived, lvReserveUsed, psmReserveUsed));

        // After the seller's transfer of RA, the router has enough RA tokens to cover the profit
        vm.assume(preState.routerRaBalance + amount >= psmProfit + lvProfit);

        // Assuming that the router has enough DS to send to the seller
        vm.assume(preState.routerDsBalance >= dsReceived);

        // No overflow occurs in the PSM rollover profit accounting
        vm.assume(preState.moduleCorePsmPoolArchiveRolloverProfit <= type(uint256).max - psmProfit - lvProfit);

        // Assuming the reserves are sufficient 
        vm.assume(preState.moduleCoreLvReserve >= lvReserveUsed);
        vm.assume(preState.moduleCorePsmReserve >= psmReserveUsed);

        // Assuming that the resulting `amountOut` of DS tokens the user will receive is sufficient
        vm.assume(dsReceived >= amountOutMin); 

        return (psmProfit, lvProfit, psmReserveUsed, lvReserveUsed);
    }

    function _assumeSwapDsForRaPreState(address seller, uint256 amount, uint256 amountOutMin) internal returns (uint256 sellerBalanceDs, uint256 routerBalanceDs) {
        Pair memory pair = moduleCore.getPairInfo(id);
        (address ds, address ct) = moduleCore.getDsCtPair(id);
        uint256 dsId = moduleCore.getDsId(id);

        address ra = pair.ra;
    
        // Assuming `amount` is are positive
        vm.assume(amount > 0);

        // Seller has symbolic amount of DS and RA
        TestERC20(ra).setSymbolicBalanceOf(seller, "sellerRaBalance");        
        TestAsset(ds).setSymbolicBalanceOf(seller, "sellerDsBalance");
        TestAsset(ds).setSymbolicAllowance(seller, address(flashSwapRouter), "sellerRouterDsBalance");

        sellerBalanceDs = TestAsset(ds).balanceOf(seller);
        // Seller has enough DS to transfer `amount` to the router
        vm.assume(sellerBalanceDs >= amount);
        // Seller has granted a sufficient allowance of DS to the router
        uint256 allowance = TestAsset(ds).allowance(seller, address(flashSwapRouter));
        vm.assume(allowance >= amount);

        // FlashSwapRouter has symbolic amount of DS and RA
        TestAsset(ds).setSymbolicBalanceOf(address(flashSwapRouter), "routerDsBalance");
        TestERC20(ra).setSymbolicBalanceOf(address(flashSwapRouter), "routerRaBalance");

        // No overflow occurs during the transfer of DS to the router:
        routerBalanceDs = TestAsset(ds).balanceOf(address(flashSwapRouter));
        vm.assume(routerBalanceDs <= type(uint256).max - amount);

        // Assuming that hiya is not 0 to prevent branching on its values,
        // and that it is sufficiently small to not overflow
        vm.assume(flashSwapRouter.getHiya(id) > 0);
        vm.assume(flashSwapRouter.getHiyeCumulated(id) > 0);
        vm.assume(flashSwapRouter.getHiyeCumulated(id) <= 1e8);
        vm.assume(flashSwapRouter.getVhiyaCumulated(id) <= 1e8);

        return (sellerBalanceDs, routerBalanceDs);
    }

    function _mockSwapDsForRaRouterCalls() internal {
        // Mocking the `lvAcceptRolloverProfit` function; depositing into LV is covered by a separate proof
        ModuleCoreMock mock = new ModuleCoreMock();
        vm.mockFunction(
            address(moduleCore), address(mock), abi.encodeWithSelector(ModuleCoreMock.lvAcceptRolloverProfit.selector)
        );

        // Mocking the result of hiya calculation with an arbitrary concrete value, assuming it doesn't overflow
        vm.mockCall(address(SwapperMathLibrary), abi.encodeWithSelector(SwapperMathLibrary.calcHIYAaccumulated.selector), abi.encode(1));
        vm.mockCall(address(SwapperMathLibrary), abi.encodeWithSelector(SwapperMathLibrary.calcVHIYAaccumulated.selector), abi.encode(1));
    }

    function test_swapRaForDs_rollover(uint256 amount, uint256 amountOutMin) public {
        // Setting up a seller
        address seller = address(0xABCDE);

        // Setting up the hook;
        hook.setFlashSwapRouter(address(flashSwapRouter));

        // Assuming preconditions, defining mocks
        _assumeSwapRaForDsPreState(seller, amount);
        _stateSnapshotSwap(preState, seller);
        (uint256 psmProfit, uint256 lvProfit, uint256 psmReserveUsed, uint256 lvReserveUsed) = _mockSwapRaForDsRouterCalls(amount, amountOutMin);

        // Assuming that the rollover sale is possible
        flashSwapRouter.assumeRollOverSale(id, moduleCore.getDsId(id));

        // Calling `swapRaForDs` with symbolic values
        vm.startPrank(seller);
        uint256 amountReceived = flashSwapRouter.swapRaforDs(id, moduleCore.getDsId(id), amount, amountOutMin, IDsFlashSwapCore.BuyAprroxParams(256, 256, 1e16, 1e9, 1e9, 0.01 ether));
        vm.stopPrank();

        _stateSnapshotSwap(posState, seller);

        // Checking resulting balances of user, router
        assertEq(preState.sellerRaBalance - amount, posState.sellerRaBalance);
        assertEq(preState.sellerDsBalance + amountReceived, posState.sellerDsBalance);
        assertEq(preState.routerDsBalance - amountReceived, posState.routerDsBalance);
        assertEq(preState.routerRaBalance + amount - (psmProfit + lvProfit), posState.routerRaBalance);
        assertEq(preState.moduleCorePsmPoolArchiveRolloverProfit + psmProfit, posState.moduleCorePsmPoolArchiveRolloverProfit);
        assertEq(preState.moduleCoreRaBalance + (psmProfit + lvProfit), posState.moduleCoreRaBalance);
        assertEq(preState.moduleCorePsmReserve - psmReserveUsed, posState.moduleCorePsmReserve);
        assertEq(preState.moduleCoreLvReserve - lvReserveUsed, posState.moduleCoreLvReserve);
    }

    function test_swapDsForRa(uint256 amount, uint256 amountOutMin) public {
        // Setting up a seller
        address seller = address(0xABCDE);
        // Setting up the hook;
        hook.setFlashSwapRouter(address(flashSwapRouter));
        hook.isFlashSwap(true);

        uint256 amountIn = freshUInt256Bounded();
        hook.setAmountIn(amountIn);

        // Assuming preconditions, defining mocks
        (uint256 sellerBalanceDs, uint256 routerBalanceDs) = _assumeSwapDsForRaPreState(seller, amount, amountOutMin);
        _stateSnapshotSwap(preState, seller);
        _mockSwapDsForRaRouterCalls();

        // Assuming that the amount of DS tokens transferred in by the user is greater than or equal to `amountIn` that should be provided to the hook
        // If that is not the case, the execution will revert
        vm.assume(amount >= amountIn);

        // Expected received amount, as calculated in `SwapperMathLibrary.getAmountOutSellDs`, is sufficient:
        uint256 amountReceivedExpected = amount - amountIn;
        vm.assume(amountReceivedExpected >= amountOutMin);

        // Calling `swapDsForRa` with symbolic values
        vm.startPrank(seller);
        uint256 amountReceived = flashSwapRouter.swapDsforRa(id, moduleCore.getDsId(id), amount, amountOutMin);
        vm.stopPrank();
        
        _stateSnapshotSwap(posState, seller);

        // Checking resulting balances of user, router
        assertEq(amountReceivedExpected, amountReceived);
        assertEq(preState.sellerRaBalance + amountReceived, posState.sellerRaBalance);
        assertEq(preState.sellerDsBalance - amount, posState.sellerDsBalance);
        assertEq(preState.routerRaBalance, posState.routerRaBalance);
        /* TODO: CT, DS should be burned during the redemption */
    }
}