// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {
    IRLPExchangeRateProvider,
    IUSRPriceOracle,
    IRLPPriceOracle
} from "../../../contracts/interfaces/exchangeRateProvider/IRLPExchangeRateProvider.sol";
import {RLPExchangeRateProvider} from "../../../contracts/core/exchangeRateProviders/RLPExchangeRateProvider.sol";
import {EnvGetters} from "../Helper.sol";
import {Id, Pair} from "../../../contracts/libraries/Pair.sol";
import {IErrors} from "../../../contracts/interfaces/IErrors.sol";

/**
 * @title RLPExchangeRateTest
 * @author Cork Team
 * @notice Testing RLPExchangeRateProvider contract
 */
contract RLPExchangeRateTest is Test {
    // Define mainnet addresses
    address constant WST_USR = 0x1202F5C7b4B9E47a1A484E8B270be34dbbC75055;
    address constant USR_PRICE_ORACLE = 0x7f45180d6fFd0435D8dD695fd01320E6999c261c;
    address constant RLP_PRICE_ORACLE = 0xaE2364579D6cB4Bbd6695846C1D595cA9AF3574d;

    EnvGetters internal env = new EnvGetters();

    function setUp() public {
        string memory forkUrl = envStringNoRevert("FORK_URL");
        uint256 forkBlock = envUintNoRevert("FORK_BLOCK");

        if (forkBlock == 0 || keccak256(abi.encodePacked(forkUrl)) == keccak256("")) {
            vm.skip(true, "no fork url and block was found");
        }

        vm.createSelectFork(forkUrl, forkBlock);
    }

    function envStringNoRevert(string memory key) internal view returns (string memory) {
        try env.envString(key) returns (string memory value) {
            return value;
        } catch {
            return "https://eth.llamarpc.com";
        }
    }

    function envUintNoRevert(string memory key) internal view returns (uint256) {
        try env.envUint(key) returns (uint256 value) {
            return value;
        } catch {
            return 21839525;
        }
    }

    function test_RLPExchangeRateProvider() public {
        IRLPExchangeRateProvider rlpExchangeRateProvider =
            new RLPExchangeRateProvider(WST_USR, USR_PRICE_ORACLE, RLP_PRICE_ORACLE);
        uint256 exchangeRate = rlpExchangeRateProvider.rate();

        uint256 wstUsrPrice = IERC4626(WST_USR).convertToAssets(1 ether);
        (uint256 usrUSDPrice,,,) = IUSRPriceOracle(USR_PRICE_ORACLE).lastPrice();
        (uint256 rlpUSDPrice,) = IRLPPriceOracle(RLP_PRICE_ORACLE).lastPrice();

        // exchange rate = (wstUsrPrice * usrUSDPrice) / rlpUSDPrice
        uint256 expectedExchangeRate = (wstUsrPrice * usrUSDPrice) / rlpUSDPrice;
        assertEq(exchangeRate, expectedExchangeRate);

        // Mock market id
        Id marketId = Id.wrap(
            keccak256(
                abi.encode(
                    Pair(
                        WST_USR, address(0), 1000000000000000000, 1000000000000000000, address(rlpExchangeRateProvider)
                    )
                )
            )
        );
        exchangeRate = rlpExchangeRateProvider.rate(marketId);
        assertEq(exchangeRate, expectedExchangeRate);
    }

    function test_RevertWhenZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(IErrors.ZeroAddress.selector));
        new RLPExchangeRateProvider(address(0), USR_PRICE_ORACLE, RLP_PRICE_ORACLE);

        vm.expectRevert(abi.encodeWithSelector(IErrors.ZeroAddress.selector));
        new RLPExchangeRateProvider(WST_USR, address(0), RLP_PRICE_ORACLE);

        vm.expectRevert(abi.encodeWithSelector(IErrors.ZeroAddress.selector));
        new RLPExchangeRateProvider(WST_USR, USR_PRICE_ORACLE, address(0));
    }
}
