// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

contract SimpleAuction {
    
    // auction parameters
    address payable public beneficiary;
    uint public auctionEndTime; 
    
    // current state
    address public highestBidder;
    uint public highestBid;
    
    // allow losing bidders to reclaim
    mapping(address => uint) public fundsToReturn;
    
    // indicator
    bool auctionEnded;
    
    // events
    event HighestBidIncreased(address bidder, uint amount);
    event AuctionOver(address winner, uint amount);
    
    // errors
    /// Auction already ended
    error AuctionEnded();
    /// As high or a higher bid already exists
    error BidTooLow(uint topBid);
    /// Auction not yet over
    error AuctionNotEnded();

    constructor(
        address payable _beneficiary, 
        uint auctionTime
    ){
        beneficiary = _beneficiary;
        auctionEndTime = block.timestamp + auctionTime;
    }
    
    function bid() public payable {
        
        if (block.timestamp > auctionEndTime) 
            revert AuctionEnded();
            
        if (msg.value <= highestBid) 
            revert BidTooLow(highestBid);
                   
        if(highestBid > 0){
            fundsToReturn[highestBidder] += highestBid; // allow previous highest bidder to remove funds
        }
        
        highestBidder = msg.sender;
        highestBid = msg.value;
        emit HighestBidIncreased(highestBidder, highestBid);
    }
    
    // users can withdraw failed bids 
    function withdraw() public returns(bool) {
        uint amount = fundsToReturn[msg.sender];
        
        if (amount > 0) {
            fundsToReturn[msg.sender] = 0; // amount is now about to be sent
            
            if( !payable(msg.sender).send(amount) ) {
                fundsToReturn[msg.sender] = amount; // top back up if withdraw fails
                return false;
            }
        }
        return true;
    }
    
    // benefactor will end auction to pay themselves
    function AuctionEnd() public {
        if (block.timestamp <= auctionEndTime)
            revert AuctionNotEnded();
            
        if (auctionEnded) 
            revert AuctionEnded();
            
        auctionEnded = true;
        emit AuctionOver(highestBidder, highestBid);
        beneficiary.transfer(highestBid); // pay the benefactor
    }
}
