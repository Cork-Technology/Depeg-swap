pragma solidity 0.8.24;

interface IHedgeUnit {
    // Events
    event Mint(address indexed minter, uint256 amount);
    event Dissolve(address indexed dissolver, uint256 amount, uint256 dsAmount, uint256 paAmount);
    event MintingPausedSet(bool paused);
    event MintCapUpdated(uint256 newMintCap);

    // Errors
    error MintingPaused();
    error InvalidAmount();
    error MintCapExceeded();
    error InvalidValue();

    // Read functions
    function mintingPaused() external view returns (bool);
    function mintCap() external view returns (uint256);

    //functions
    function mint(uint256 amount) external;
    function dissolve(uint256 amount) external returns (uint256 dsAmount, uint256 paAmount);
    function setMintingPaused(bool _paused) external;
    function updateMintCap(uint256 _newMintCap) external;
}
