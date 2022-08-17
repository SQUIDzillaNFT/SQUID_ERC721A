// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "./ERC721A.sol";
import "./Ownable.sol";
import "./SafeMath.sol"; 

/*
* ERC721A Gas Optimized Minting
*  https://twitter.com/SQUIDzillaz0e
*  Feel free to use and Modify.
*  Change contract name "ERC721_SQUID"
*  to your own Contract name Before Deployment
*/


contract ERC721_SQUID is ERC721A, Ownable {
    using SafeMath for uint256;

    /*
     * @dev Set Initial Parameters Before deployment
     * settings are still fully updateable after deployment
     * Max Mint overall, Max NFTs in collection, Max Mint during Presale period
     * as well as Private/Presale price adn Public Mint price.
     * Public are easily retrieved on Etherscan/FrontEnd
     */
    uint256 public MAX_MINTS = 100;
    uint256 public MAX_SUPPLY = 5555;
    uint256 public mintRate = 0.07 ether;
    uint256 public privateMintPrice = 0.055 ether;
    uint256 public MAX_MINT_WHITELIST = 50;
    /*
    * @Dev Booleans for sale states. 
    * salesIsActive must be true in any case to mint
    * privateSaleIsActive must be true in the case of Whitelist mints
    * If you do not want a WL period or a Presale Period keep
    * privateSalesIsActive set to False and it will bypass the sale period Entirely.
    */
    bool public saleIsActive = false;
    bool public privateSaleIsActive = true;
    /*
    * @Dev Whitelist Struct and Mappings
    * the address and amount minted to keep track of how many you may mint
    * Stores Data about the wallet and their Mint History
    */
    struct Whitelist {
        address addr;
        uint256 hasMinted;
    }

    mapping(address => Whitelist) public whitelist;

    address[] whitelistAddr;

    /*
     * @dev Set base URI, Make sure when dpeloying if you plan to Have an 
     * Unrevealed Sale or Period you Do not Deploy with your Revealed
     * base URI here or they will mint With your revealed Images Showing
     * I reccomend setting an Incorrect or an Unrevealed URI here, You can also leave
     * it Not filled in and Update it with the setBaseURI Function at any Point
     */
    string public baseURI = "ipfs://URI_GOES_HERE_FOR_METADATA/";
    
    /*
     * @dev Set your Collection/Contract name and Token Ticker
     * below. Constructor Parameter cannot be changed after
     * contract deployment.
     */
    constructor() ERC721A("COLLECTION_NAME_HERE", "TICKER_HERE") {}

    /*
     *  @dev
     * Set presale price to mint per NFT
     */
    function setPrivateMintPrice(uint256 _price) external onlyOwner {
        privateMintPrice = _price;
    }

    /*
     *@dev
     * Set publicsale price to mint per NFT
     */
    function setPublicMintPrice(uint256 _price) external onlyOwner {
        mintRate = _price;
    }

    /*
    * @dev mint funtion with _to address. no cost mint
    *  by contract owner/deployer
    */
    function Devmint(uint256 quantity, address _to) external onlyOwner {
        require(saleIsActive, "Sale must be active to mint");
        require(totalSupply() + quantity <= MAX_SUPPLY, "Not enough tokens left");
        _safeMint(_to, quantity);
    }

    /*
    * @dev mint function and checks for saleState and mint quantity
    * Includes Private/public sale checks and quantity minted.
    * ** Updated to only look for whitelist during Presale state only
    * Use Max Mints more of a max perwallet than how many can be minted.
    * This remedied the bug of not being able to mint in Public sale after
    * a presale mint has occured. or a mint has occured and was transfered to a different wallet.
    */   
    function mint(uint256 quantity) external payable {
        require(saleIsActive, "Sale must be active to mint");
        // _safeMint's second argument now takes in a quantity, not a tokenId.
        require(quantity + _numberMinted(msg.sender) <= MAX_MINTS, "Exceeds Max Allowed Mint Count");
        require(totalSupply() + quantity <= MAX_SUPPLY, "Not enough tokens left to Mint");

        if(privateSaleIsActive) {
           require(msg.value >= (privateMintPrice * quantity), "Not enough ETH sent");
           require(quantity <= MAX_MINT_WHITELIST, "Above max Mint Whitelist count");
           require(isWhitelisted(msg.sender), "Is not whitelisted");
           require(
                whitelist[msg.sender].hasMinted.add(quantity) <=
                    MAX_MINT_WHITELIST,
                "Exceeds Max Mint During Whitelist Period"
            );
            whitelist[msg.sender].hasMinted = whitelist[msg.sender]
                .hasMinted
                .add(quantity);
        } else { 
            require((balanceOf(msg.sender) + quantity) <= MAX_MINTS, "Cant Mint any More Tokens");
            require((mintRate * quantity) <= msg.value, "Value below price");
        }


        if (totalSupply() < MAX_SUPPLY){
        _safeMint(msg.sender, quantity);
        }
    }

    /*
     * @dev Set Max Mints allowed by any one single
     * wallet during the entirety of the Mint.
     */
    function setMaxMints(uint256 _max) external onlyOwner {
        MAX_MINTS = _max;
    }

    /*
     * @dev Set new Max Mint while in Whitelist
     * sale period. Total number of NFTs one can mint during
     * This period per wallet.
     */
    function setMaxMintsWhiteList(uint256 _wlMax) external onlyOwner {
        MAX_MINT_WHITELIST = _wlMax;
    }

    /*
     * @dev Set new Base URI
     * useful for setting unrevealed uri to revealed Base URI
     * same as a reveal switch/state but not the extraness
     */
    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        baseURI = newBaseURI;
    }

     /*
     * @dev returns Base URI on frontend/etherscan
     */
    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

     /*
     * @dev Pause sale if active, make active if paused
     */
    function setSaleActive() public onlyOwner {
        saleIsActive = !saleIsActive;
    }
    
    /*
    * @dev flip sale state from whitelist to public
    *
    */
    function setPrivateSaleActive() public onlyOwner {
        privateSaleIsActive = !privateSaleIsActive;
    }
    
    /*
     * @dev Withdrawl function, Contract ETH balance
     * to owner wallet address.
     */
    function withdraw() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
    
    /*
    * @dev Alternative withdrawl
    * mint funs to a specified address
    * 
    */
    function altWithdraw(uint256 _amount, address payable _to)
        external
        onlyOwner
    {
        require(_amount > 0, "Withdraw must be greater than 0");
        require(_amount <= address(this).balance, "Amount too high");
        (bool success, ) = _to.call{value: _amount}("");
        require(success);
    }

    /*
    * @dev Set Whitelist address
    * array - format must be: ["address1","address2"]
    * 
    */
    function setWhitelistAddr(address[] memory addrs) public onlyOwner {
        whitelistAddr = addrs;
        for (uint256 i = 0; i < whitelistAddr.length; i++) {
            addAddressToWhitelist(whitelistAddr[i]);
        }
    }

    /*
    * @dev Add a single Wallet
    * address to whitelist
    * 
    */
    function addAddressToWhitelist(address addr)
        public
        onlyOwner
        returns (bool success)
    {
        require(!isWhitelisted(addr), "Already whitelisted");
        whitelist[addr].addr = addr;
        success = true;
    }
    
    /*
    * @dev return a boolean true or false if
    * an address is whitelisted on etherscan
    * or frontend
    */
    function isWhitelisted(address addr)
        public
        view
        returns (bool isWhiteListed)
    {
        return whitelist[addr].addr == addr;
    }

}