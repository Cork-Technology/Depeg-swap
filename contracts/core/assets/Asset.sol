// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {IExpiry} from "../../interfaces/IExpiry.sol";
import {IRates} from "../../interfaces/IRates.sol";
import {CustomERC20Permit} from "../../libraries/ERC/CustomERC20Permit.sol";
import {ModuleCore} from "./../ModuleCore.sol";
import {IReserve} from "./../../interfaces/IReserve.sol";
import {Id} from "./../../libraries/Pair.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IErrors} from "./../../interfaces/IErrors.sol";
/**
 * @title Contract for Adding Exchange Rate functionality
 * @author Cork Team
 * @notice Adds Exchange Rate functionality to Assets contracts
 */

abstract contract ExchangeRate is IRates {
    uint256 internal rate;

    constructor(uint256 _rate) {
        rate = _rate;
    }

    /**
     * @notice returns the current exchange rate
     */
    function exchangeRate() external view override returns (uint256) {
        return rate;
    }
}

/**
 * @title Contract for Adding Expiry functionality to DS
 * @author Cork Team
 * @notice Adds Expiry functionality to Assets contracts
 * @dev Used for adding Expiry functionality to contracts like DS
 */
abstract contract Expiry is IExpiry {
    uint256 internal immutable EXPIRY;
    uint256 internal immutable ISSUED_AT;

    constructor(uint256 _expiry) {
        if (_expiry != 0 && _expiry < block.timestamp) {
            revert Expired();
        }

        EXPIRY = _expiry;
        ISSUED_AT = block.timestamp;
    }

    /**
     * @notice returns if contract is expired or not(if timestamp==0 then contract not having any expiry)
     */
    function isExpired() external view virtual returns (bool) {
        if (EXPIRY == 0) {
            return false;
        }

        return block.timestamp >= EXPIRY;
    }

    /**
     * @notice returns expiry timestamp of contract
     */
    function expiry() external view virtual returns (uint256) {
        return EXPIRY;
    }

    function issuedAt() external view virtual returns (uint256) {
        return ISSUED_AT;
    }
}

contract PermissionedMarketWhitelist is AccessControl, IErrors {
    address public assetFactory;
    address public moduleCore;
    address public router;
    address public hook;

    mapping(Id => bool) public isPermissioned;

    bytes32 public constant ADMIN = keccak256("ADMIN");
    bytes32 public constant MEMBER = keccak256("MEMBER");

    constructor(address _assetFactory, address _moduleCore, address _router, address _hook) {
        assetFactory = _assetFactory;
        moduleCore = _moduleCore;
        router = _router;
        hook = _hook;
    }

    function _computeRole(Id id, bytes32 role) internal returns (bytes32) {
        return keccak256(abi.encodePacked(id, role));
    }

    modifier onlyAdminAndPermissioned(Id id) {
        if (!hasRole(id, ADMIN, msg.sender) && isPermissioned[id]) {
            revert AccessControlUnauthorizedAccount(caller, ADMIN);
        }

        _;
    }

    modifier onlyModuleCore() {
        if (msg.sender != moduleCore) {
            revert NotModuleCore();
        }

        _;
    }

    function onPermissionedMarketCreation(Id id, address admin) external onlyModuleCore {
        if (isPermissioned[id]) {
            revert AlreadyInitialized();
        }
    }

    function isMember(Id id, address who) external view returns (bool) {
        return hasRole(id, MEMBER, who);
    }

    function isAdmin(Id id, address who) external view returns (bool) {
        return hasRole(id, ADMIN, who);
    }

    function isParticipant(Id id, address who) external view returns (bool) {
        return hasRole(id, MEMBER, who) || hasRole(id, ADMIN, who);
    }

    function hasRole(Id id, bytes32 role, address account) public view returns (bool) {
        if (!isPermissioned[id]) {
            return true;
        } else {
            role = _computeRole(id, role);
            return super.hasRole(role, account);
        }
    }

    function addMember(Id id, address member) external onlyAdminAndPermissioned(id) {
        bytes32 memberRole = _computeRole(id, MEMBER);

        _grantRole(memberRole, member);
    }

    function addAdmin(Id id, address newAdmin) external onlyAdminAndPermissioned(id) {
        bytes32 adminRole = _computeRole(id, ADMIN);

        _grantRole(adminRole, newAdmin);
    }

    /**
     * @notice Revokes member access for a specific market
     * @param id The market ID
     * @param member The address to remove membership from
     */
    function revokeMember(Id id, address member) external onlyAdminAndPermissioned(id) {
        bytes32 memberRole = _computeRole(id, MEMBER);

        _revokeRole(memberRole, member);
    }

    /**
     * @notice Revokes admin access for a specific market
     * @param id The market ID
     * @param admin The address to remove admin rights from
     * @dev Admin cannot revoke their own admin rights
     */
    function revokeAdmin(Id id, address admin) external onlyAdminAndPermissioned(id) {
        // Prevent admins from revoking their own access to avoid accidental lockouts
        if (admin == msg.sender) {
            revert("Cannot revoke your own admin rights");
        }

        bytes32 adminRole = _computeRole(id, ADMIN);

        _revokeRole(adminRole, admin);
    }

    /**
     * @notice Allows an admin to renounce their own admin rights
     * @param id The market ID
     * @dev Use with caution
     */
    function renounceAdmin(Id id) external onlyAdminAndPermissioned(id) {
        bytes32 role = _computeRole(id, ADMIN);

        _revokeRole(role, msg.sender);
    }

    /**
     * @notice Allows a member to renounce their member rights
     * @param id The market ID
     * @dev Use with caution
     */
    function renounceMember(Id id) external {
        bytes32 role = _computeRole(id, MEMBER);

        _revokeRole(role, msg.sender);
    }
}

/**
 * @title Assets Contract
 * @author Cork Team
 * @notice Contract for implementing assets like DS/CT etc
 */
contract Asset is ERC20Burnable, IErrors, CustomERC20Permit, Ownable, Expiry, ExchangeRate, IReserve {
    uint256 internal immutable DS_ID;

    string public pairName;

    Id public marketId;

    ModuleCore public moduleCore;

    address public factory;

    PermissionedMarketWhitelist whitelist;

    modifier onlyFactory() {
        if (_msgSender() != factory) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }

        _;
    }

    modifier onlyParticipant(address who) {
        if (!whitelist.isParticipant(who)) {
            revert OnlyMember();
        }

        _;
    }

    constructor(string memory _pairName, address _owner, uint256 _expiry, uint256 _rate, uint256 _dsId)
        ExchangeRate(_rate)
        ERC20(_pairName, _pairName)
        CustomERC20Permit(_pairName)
        Ownable(_owner)
        Expiry(_expiry)
    {
        pairName = _pairName;
        DS_ID = _dsId;

        factory = _msgSender();
    }

    function setMarketId(Id _marketId) external onlyFactory {
        marketId = _marketId;
    }

    function setModuleCore(address _moduleCore) external onlyFactory {
        moduleCore = ModuleCore(_moduleCore);
    }

    function getReserves() external view returns (uint256 ra, uint256 pa) {
        uint256 epoch = moduleCore.lastDsId(marketId);

        // will return the newest epoch reserve if the contract epoch is the same
        // as the one from module core
        // if the contract epoch is 0 means that this contract is an lv token
        // so we return the newest one also
        if (epoch == DS_ID || DS_ID == 0) {
            ra = moduleCore.valueLocked(marketId, true);
            pa = moduleCore.valueLocked(marketId, false);
        } else {
            ra = moduleCore.valueLocked(marketId, DS_ID, true);
            pa = moduleCore.valueLocked(marketId, DS_ID, false);
        }
    }

    /**
     * @notice mints `amount` number of tokens to `to` address
     * @param to address of receiver
     * @param amount number of tokens to be minted
     *  @dev receipient must be a member or an admin
     */
    function mint(address to, uint256 amount) public onlyOwner onlyParticipant(to) {
        _mint(to, amount);
    }

    /**
     * @notice returns expiry timestamp of contract
     */
    function dsId() external view virtual returns (uint256) {
        return DS_ID;
    }

    function updateRate(uint256 newRate) external override onlyOwner {
        rate = newRate;
    }

    // receipient must be a member or an admin
    function transfer(address to, uint256 value) public virtual onlyParticipant(to) returns (bool) {
        super.transfer(to, value);
    }
}
