// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {ICorkHook} from "../interfaces/UniV4/IMinimalHook.sol";
import {Id, Pair} from "./../libraries/Pair.sol";
import {LiquidityToken} from "Cork-Hook/LiquidityToken.sol";
import {LpParser} from "./../libraries/LpSymbolParser.sol";
import {IErrors} from "./../interfaces/IErrors.sol";
import {ModuleCore} from "./../core/ModuleCore.sol";
import {ILpHelper} from "./../interfaces/offchain-helpers/ILpHelper.sol";
import {Asset} from "./../core/assets/Asset.sol";

contract LpHelper is ILpHelper {
    ICorkHook public hook;
    ModuleCore public moduleCore;

    constructor(address _hook, address _moduleCore) {
        hook = ICorkHook(_hook);
        moduleCore = ModuleCore(_moduleCore);
    }

    function getReserve(address lp) external view returns (uint256 raReserve, uint256 ctReserve) {
        LiquidityToken token = LiquidityToken(lp);

        if (token.owner() != address(hook)) revert IErrors.InvalidToken();

        (address ra, address ct) = LpParser.parse(token.symbol());

        // sort them correctly
        try Asset(ct).expiry() returns (uint256) {
            // do nothing, already sorted
        } catch {
            // means that the ra here is the actual ct
            (ra, ct) = (ct, ra);
        }

        (raReserve, ctReserve) = hook.getReserves(ra, ct);
    }

    function getReserve(Id id) external view returns (uint256 raReserve, uint256 ctReserve) {
        uint256 epoch = moduleCore.lastDsId(id);
        ( raReserve,  ctReserve)=_getReserve(id, epoch);
    }

    function getReserve(Id id, uint256 dsId) external view returns (uint256 raReserve, uint256 ctReserve) {
        ( raReserve,  ctReserve)=_getReserve(id, dsId);
    }

    function _getReserve(Id id, uint256 epoch) internal view returns (uint256 raReserve, uint256 ctReserve) {
        (address ra, address ct) = _getRaCt(id, epoch);
        (raReserve, ctReserve) = hook.getReserves(ra, ct);
    }

    function _getRaCt(Id id, uint256 epoch) internal view returns (address ra, address ct) {
        (,  ra,,,) = moduleCore.markets(id);

        ( ct,) = moduleCore.swapAsset(id, epoch);
    }

    function getLpToken(Id id) external view returns (address liquidityToken) {
        uint256 epoch = moduleCore.lastDsId(id);
        (address ra, address ct) = _getRaCt(id, epoch);

        liquidityToken = hook.getLiquidityToken(ra, ct);
    }

    function getLpToken(Id id, uint256 dsId) external view returns (address liquidityToken) {
        (address ra, address ct) = _getRaCt(id, dsId);

        liquidityToken = hook.getLiquidityToken(ra, ct);
    }
}
