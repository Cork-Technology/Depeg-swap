pragma solidity ^0.8.26;

interface IReserve {
    /// @notice return this pool reserve backing.
    /// note that in CT and DS this will return the associated ds id/epoch reserve
    /// e.g if the CT epoch/ds id is 2 but the newest ds id/epoch is 4
    /// this will still return backing reserve for ds id/epoch 2
    ///
    /// for LV tokens, this will always return the current backing reserve
    function getReserves() external view returns (uint256 ra, uint256 pa);
}
