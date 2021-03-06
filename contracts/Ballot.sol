pragma solidity ^0.4.18;


import {ZeroKnowledgeVerificator as ZeroKnowledgeVerificator} from "./ZeroKnowledgeVerificator.sol";


/**
* @title A contract representing a single ballot for a particular vote resp. election.
*/
contract Ballot {

    event VoteEvent(address indexed _from, bool wasSuccessful, string reason);
    event ChangeEvent(address indexed _from, bool wasSuccessful, string reason);

    modifier onlyOwner {
        require(msg.sender == _owner);
        // code for the function modified is inserted at _
        _;
    }

    struct Voter {
        address voter;
        string ciphertext;
        string proof;
        bytes random;
    }

    struct Proposal {
        uint nrVoters;
        mapping(address => bool) voted;
        Voter[] voters;
        string question;
    }

    struct SumProof {
        uint sum;
        string ciphertext;
        string proof;
    }

    address private _owner;

    bool private _votingIsOpen;

    Proposal private _proposal;

    SumProof private _sumProof;


    ZeroKnowledgeVerificator _zkVerificator;

    /**
     * @param question The question the voters are getting asked.
     */
    function Ballot(string question, ZeroKnowledgeVerificator zkVerificator) public {
        _votingIsOpen = false;

        _proposal.question = question;
        _proposal.voters.length = 0;
        _proposal.nrVoters = 0;

        _zkVerificator = zkVerificator;

        _owner = msg.sender;
    }

    /**
     * @dev Opens the voting process. Only the owner of this contract is allowed to call this method.
     */
    function openVoting() external onlyOwner {
        ChangeEvent(msg.sender, true, "Opened voting");
        _votingIsOpen = true;
    }

    /**
     * @dev Closes the voting process. Only the owner of this contract is allowed to call this method.
     */
    function closeVoting() external onlyOwner {
        ChangeEvent(msg.sender, true, "Closed voting");
        _votingIsOpen = false;
    }

    /**
     * Consider the ElGamal multiplicative (i.e. additive homomorphic) encryption to be of the form:
     *
     *   E(m) = (G, H) = (g^r, h^r * g^m), with h = g^x and m = message
     *
     * @dev Note, this function does not assume anything about how the ciphertext resp. the proof
     * is actually represented. This is the domain of the caller.
     *
     * @param ciphertext   The ciphertext, i.e. a string representing (G, H)
     * @param proof        The corresponding membership proof.
     * @param random       The random number used in the ciphertext. Note, this value is encrypted.
     *
     * @return bool, string True if vote is accepted, false otherwise, along with the reason why.
     */
    function vote(string ciphertext, string proof, bytes random) external returns (bool, string) {
        // check whether voting is still allowed
        if (!_votingIsOpen) {
            VoteEvent(msg.sender, false, "Voting is closed");
            return (false, "Voting is closed");
        }

        bool hasVoted = _proposal.voted[msg.sender];
        // disallow multiple votes
        if (hasVoted) {
            VoteEvent(msg.sender, false, "Voter already voted");
            return (false, "Voter already voted");
        }

        bool validZkProof = _zkVerificator.verifyProof(proof);
        if (!validZkProof) {
            VoteEvent(msg.sender, false, "Invalid zero knowledge proof");
            return (false, "Invalid zero knowledge proof");
        }

        _proposal.voted[msg.sender] = true;
        _proposal.voters.push(Voter({voter : msg.sender, ciphertext : ciphertext, proof : proof, random : random}));

        _proposal.nrVoters += 1;

        VoteEvent(msg.sender, true, "Accepted vote");

        return (true, "Accepted vote");
    }

    /**
     * @param sum The cleartext sum of all votes, i.e. the cleartext result of the addition of all submitted votes.
     * @param ciphertext The ciphertext containing the encrypted sum as result of the addition of all submitted votes.
     * @param proof The corresponding proof, ensuring that the ciphertext actually contains the sum.
     */
    function setSumProof(uint sum, string ciphertext, string proof) public onlyOwner {
        _sumProof = SumProof({sum : sum, ciphertext : ciphertext, proof : proof});
    }

    /**
     * @return sum The cleartext sum of all votes, i.e. the cleartext result of the addition of all submitted votes.
     * @return ciphertext The ciphertext containing the encrypted sum as result of the addition of all submitted votes.
     * @return proof The corresponding proof, ensuring that the ciphertext actually contains the sum.
     */
    function getSumProof() public constant returns (uint sum, string ciphertext, string proof) {
        sum = _sumProof.sum;
        ciphertext = _sumProof.ciphertext;
        proof = _sumProof.proof;
    }

    /**
     * @dev Returns the question to ask voters, set on construction of this contract.
     *
     * @return question The question to ask voters.
     */
    function getProposedQuestion() public constant returns (string question) {
        question = _proposal.question;
    }

    /**
     * @dev Returns the total number of voters which have currently voted.
     *
     * @return totalVotes The total number of voters which have currently voted.
     */
    function getTotalVotes() public constant returns (uint totalVotes) {
        totalVotes = _proposal.nrVoters;
    }

    /**
     * @dev Returns the vote submitted by the voter at the given index.
     *
     * @return voter        The address of the voter.
     * @return ciphertext   The ciphertext.
     * @return proof        The proof.
     * @return random       The random value used in the ciphertext. Note, that this value is encrypted.
     */
    function getVote(uint index) external constant returns (address voter, string ciphertext, string proof, bytes random) {
        return (_proposal.voters[index].voter, _proposal.voters[index].ciphertext, _proposal.voters[index].proof, _proposal.voters[index].random);
    }

    /**
     * @dev Destroys this contract. May be called only by the owner of this contract.
     */
    function destroy() public onlyOwner {
        ChangeEvent(msg.sender, true, "Destroyed contract");
        selfdestruct(_owner);
    }

}
