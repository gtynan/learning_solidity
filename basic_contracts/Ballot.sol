// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

contract Ballot {
    
    // person who votes on a proposal
    struct Voter {
        uint weight;
        bool voted;
        address delegate;
        uint vote;
    }
    
    // things that can be voted on 
    struct Proposal {
        bytes32 name; 
        uint voteCount;
    }
    
    // contract creator
    address public chairperson;
    
    // people who can vote
    mapping(address => Voter) public voters;
    
    // proposals to vote on
    Proposal[] public proposals;
    
    // intialise contract
    constructor(bytes32[] memory proposalNames) {
        chairperson = msg.sender;
        giveRightToVote(chairperson);
        
        // add all proposals
        for(uint i = 0; i < proposalNames.length; i++) {
            // add Proposal to list
            proposals.push(
                Proposal({
                    name: proposalNames[i],
                    voteCount: 0
                })
            );
        }
    }
    
    // whitelist said address to vote
    function giveRightToVote(address voter) public {
        require(msg.sender == chairperson, "Only chairperson can call this function");
        require(!voters[voter].voted, "Already voted");
        require(voters[voter].weight == 0);
        voters[voter].weight = 1;
    }
    
    // give your vote to someone else
    function delegate(address to) public { 
        // user that sent the request
        Voter storage sender = voters[msg.sender];
        
        require(!sender.voted, "Cant have already voted");
        require(sender.weight > 0, "Must be able to vote");
        
        // ensure no recursive loop back to sender
        while(voters[to].delegate != address(0)) {
            to = voters[to].delegate;
            require(to != msg.sender, "Cannot recursively delegate to yourself");
        }
        
        // person to vote on your behalf 
        Voter storage delegateTo = voters[to];
        
        if (delegateTo.voted) {
            vote(delegateTo.vote); // vote for who your delegator voted for
        } else {
            delegateTo.weight += sender.weight; // give delegator addittional voting weigth
            sender.voted = true;
        }
        
        // mark as having delegated
        sender.delegate = to;
        
    }
    
    function vote(uint i) public {
        Voter storage sender = voters[msg.sender];
        require(!sender.voted, "Already voted");
        require(sender.weight > 0, "Not allowed vote");
        
        sender.voted = true;
        sender.vote = i;
        proposals[i].voteCount += sender.weight;
    }
    
    function getWinningProposal() private view returns (uint winningIndex){
        uint winningCount = 0;
        
        for(uint i = 0; i < proposals.length; i++){
            if(winningCount < proposals[i].voteCount) {
                winningCount = proposals[i].voteCount;
                winningIndex = i;
            }
        }
    }
    
    function getWinningName() public view returns (bytes32 winningName) {
        winningName = proposals[getWinningProposal()].name;
    }
    
}