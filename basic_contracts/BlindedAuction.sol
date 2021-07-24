// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

contract BlindBid {
    
    // user encodes their bid and sends a deposit
    // deposit should be larger than the value encoded. 
    // The bid = value with the remainder of the deposit returned
    struct Bid{
        bytes32 blindBid;
        uint deposit;
    }
    
    address payable public beneficiary;
    uint public biddingEnd;
    uint public revelEnd;
    bool ended;
    
    // map an address to all the bids they make
    mapping(address => Bid[]) bids;
    
    address public highestBidder;
    uint public highestBid;
    
    // blinded bids that have been revealed but did not win 
    mapping(address => uint) pendingReturns;
    
    /// Who won the auction
    event AuctionEnded(address highestBidder, uint highestBid);
    
    /// Too early to reveal bids
    error TooEarly(uint time);
    
    /// Too late to reveal bids
    error TooLate(uint time);
    
    /// Auction was closed already
    error AuctionAlreadyEnded();
    
    // function using this will fail if called after _time
    modifier onlyBefore(uint _time){
        if (block.timestamp >= _time) revert TooLate(_time);
        // underscores are for the fucntion this is used with to follow
        _; 
    }
    
    // function using this will fail if called before _time
    modifier onlyAfter(uint _time) {
        if (block.timestamp < _time) revert TooEarly(_time);
        _;
    }
    
    constructor(
        uint _biddingTime,
        uint _revelTime
    ){
        // contract caller is beneficiary
        beneficiary = payable(msg.sender);
        
        biddingEnd = block.timestamp + _biddingTime;
        revelEnd = biddingEnd + _revelTime;
    }
    
    function bid(bytes32 _bid) 
        public 
        payable 
        onlyBefore(biddingEnd)
    {
        bids[msg.sender].push(Bid({
                blindBid: _bid, 
                deposit: msg.value
        }));
    }
    
    function revealBid(
        uint[] memory _values,  
        bool[] memory _fake, 
        bytes32[] memory _secret
    ) 
        public
        onlyAfter(biddingEnd)
        onlyBefore(revelEnd)
    {
        uint length = bids[msg.sender].length;
        require(length == _values.length, "n _value doesnt match n bids");
        require(length == _fake.length, "n _fake doesnt match n bids");
        require(length == _secret.length, "n _secret doesnt match n bids");
        
        uint refund;
        
        // loop through bids to calculate refund
        for(uint i=0; i < length - 1; i++){
            // stroage as we want to edit the actual bid 
            Bid storage bidToCheck = bids[msg.sender][i];
            (uint value, bool fake, bytes32 secret) = (_values[i], _fake[i], _secret[i]);
            
            if(bidToCheck.blindBid != keccak256(abi.encodePacked(value, fake, secret))){
                // do nothing
                continue;
            }
            
            refund += bidToCheck.deposit;
            if (!fake &&  bidToCheck.deposit >= value){
                if (placeBid(msg.sender, value)) 
                    refund -= value; 
            }
            // Make it impossible for the sender to re-claim
            // the same deposit.
            bidToCheck.blindBid = bytes32(0);
        }
        payable(msg.sender).transfer(refund); 
    }
    
    function withdraw() public onlyAfter(biddingEnd) {
        uint amount = pendingReturns[msg.sender];
        
        if (amount > 0) {
            pendingReturns[msg.sender] = 0;
            payable(msg.sender).transfer(amount);
        }
    }
    
    function auctionEnd() public onlyAfter(revelEnd) {
        if(ended) revert AuctionAlreadyEnded();
        emit AuctionEnded(highestBidder, highestBid);
        ended = true;
        beneficiary.transfer(highestBid);
    }
    
    function placeBid(address bidder, uint value) 
        internal 
        returns(bool)
    {
        // value too small
        if (value <= highestBid) {
            return false;
        }
        // if we have a highest bidder endable their refund
        if(highestBidder != address(0)){
            pendingReturns[highestBidder] += highestBid;
        }
        highestBidder = bidder;
        highestBid = value;
        return true;
    }
}
