// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Election {
    uint256 private VoterCounter = 0;
    uint256 private CandidateCounter = 0;
    uint256 private AreaCounter = 0;

    struct Voter {
        string forename;
        string surname;
        uint256 areaID;
        uint256 uid;
        bool voted;
        address user;
    }

    struct Candidate {
        string forename;
        string surname;
        uint256 areaID;
        uint256 uid;
        address user;
        uint256 voteCount;
    }

    struct Area {
        string name;
        uint256 id;
        Candidate candidate;
    }

    enum Phase {
        REGISTRATION,
        VOTING,
        FINISHED
    }

    mapping(address => Voter) public voters;
    Candidate[] public candidates;
    Area[] public areas;
    Phase public currentPhase;
    address public electionManager;

    event PhaseAdvanced(
        Phase phase
    );

    event WinningCandidate(
        Candidate candidate,
        Area area
    );

    modifier onlyManager() {
        require(msg.sender == electionManager);
        _;
    }

    modifier onlyRegistration() {
        require(currentPhase == Phase.REGISTRATION);
        _;
    }

    modifier onlyVoting() {
        require(currentPhase == Phase.VOTING);
        _;
    }

    modifier onlyFinished() {
        require(currentPhase == Phase.FINISHED);
        _;
    }

    constructor (
        string[] memory _areas
    ) {
        for (uint256 i = 0; i < _areas.length; i++) {
            AreaCounter++;
            Area memory newArea = Area(_areas[i], AreaCounter, Candidate("", "", 0, 0, address(0x0), 0));
            areas.push(newArea);
        }

        currentPhase = Phase.REGISTRATION;
        electionManager = msg.sender;
    }

    function advancePhase() public onlyManager {
        if (currentPhase == Phase.REGISTRATION) {
            currentPhase = Phase.VOTING;
            emit PhaseAdvanced(currentPhase);
        } else if (currentPhase == Phase.VOTING) {
            currentPhase = Phase.FINISHED;
            emit PhaseAdvanced(currentPhase);
        }
    }

    function getCurrentPhase() public view returns (Phase) {
        return currentPhase;
    }

    function getElectionManager() public view returns (address) {
        return electionManager;
    }

    function getAreas() public view returns (Area[] memory) {
        return areas;
    }

    function registerVoter(string memory forename, string memory surname, uint256 area) public onlyRegistration {

        if (voters[msg.sender].uid != 0) {
            revert("Voter already exists");
        }

        VoterCounter++;
        Voter memory newVoter = Voter(forename, surname, area, VoterCounter, false, msg.sender);
        voters[msg.sender] = newVoter;
    }

    function addCandidate(string memory forename, string memory surname, uint256 area) public onlyRegistration {

        for (uint256 i = 0; i < candidates.length; i++) {
            if (keccak256(abi.encodePacked(msg.sender)) == keccak256(abi.encodePacked(candidates[i].user))) {
                revert("Candidate already exists");
            }
        }

        CandidateCounter++;
        Candidate memory newCandidate = Candidate(forename, surname, area, CandidateCounter, msg.sender, 0);
        candidates.push(newCandidate);
    }

    function getVoterByAddress(address voterAddress) public view returns (Voter memory) {
        Voter memory voter = voters[voterAddress];
        if (voter.uid == 0) {
            revert("Voter Not Found");
        }

        return voter;
    }

    function getCandidateByID(uint256 id) public view returns (Candidate memory) {
        for (uint256 i = 0; i < candidates.length; i++) {
            if (candidates[i].uid == id) {
                return candidates[i];
            }
        }

        revert("Candidate Not Found");
    }

    function voteForCandidate(uint256 candidateID) public onlyVoting {

        Voter memory voter = getVoterByAddress(msg.sender);
        if (voter.uid == 0) {
            revert("You are not registered.");
        }

        Candidate memory candidate = getCandidateByID(candidateID);
        if (candidate.uid == 0) {
            revert("Invalid candidate ID.");
        }

        if (voter.areaID != candidate.areaID) {
            revert("You cannot vote for a candidate in this area.");
        }

        if (voter.voted) {
            revert("You cannot vote twice");
        }

        candidate.voteCount += 1;
        candidates[candidate.uid - 1] = candidate;

        voter.voted = true;
        voters[msg.sender] = voter;
    }

    function declareAreaWinners() public onlyManager onlyFinished {

        for (uint256 i = 0; i < areas.length; i++) {
            Candidate memory winningCandidate;

            for (uint256 j = 0; j < candidates.length; j++) {

                if (areas[i].id == candidates[j].areaID) {

                    if (winningCandidate.voteCount < candidates[j].voteCount) {
                        winningCandidate = candidates[j];
                    }
                }
            }

            areas[i].candidate = winningCandidate;
            emit WinningCandidate(winningCandidate, areas[i]);
        }
    }
}