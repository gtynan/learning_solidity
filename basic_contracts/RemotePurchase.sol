// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

contract RemotePurchase{
    
    uint public value; 
    address payable public seller;
    address payable public buyer;
    
    enum State { Created, Locked, Release, Inactive }
    
    State public state;
    
    /// value must be divisable by two as contains 50% deposit
    error ValueNotEven();
    
    /// only seller can all this function
    error OnlySeller();
    /// only buyer can call this function
    error OnlyBuyer();
    /// can't call function on current state
    error IncorrectState();
    
    modifier condition(bool _bool) {
        require(_bool);
        _;
    }
    
    modifier onlySeller() {
        if (msg.sender != seller) revert OnlySeller();
        _;
    }
    
    modifier onlyBuyer() {
        if (msg.sender != buyer) revert OnlyBuyer();
        _;
    }
    
    modifier inState(State _state) {
        if(state != _state) revert IncorrectState();
        _;
    }
    
    event ContractAborted();
    event PurchaseConfirmed();
    event OrderReceived();
    event SellerRefunded();
    
    constructor() payable {
        seller = payable(msg.sender);
        value = msg.value / 2; // pay double to secure transaction
        
        if (value*2 != msg.value) revert ValueNotEven();
    }
    
    function abort() public onlySeller inState(State.Created) {
        emit ContractAborted();
        state = State.Inactive;
        seller.transfer(value*2);
    }
    
    // buyer confirms they wish to enter the contract
    function confirmPurchase() 
        public  
        inState(State.Created) 
        condition(msg.value == value*2)
        payable
    {
        emit PurchaseConfirmed();
        buyer = payable(msg.sender);
        state = State.Locked;
    }
    
    // buyer confirms they received the item
    function confirmReceived() public onlyBuyer inState(State.Locked){
        emit OrderReceived();
        state = State.Release;
        buyer.transfer(value); // refund their deposit
    }
    
    // seller can withdraw their funds
    function refundSeller() public onlySeller inState(State.Release){
        emit SellerRefunded();
        state = State.Inactive;
        seller.transfer(value*3);
    }
    
}
