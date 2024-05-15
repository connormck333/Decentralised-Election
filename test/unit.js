const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Election", function () {

    const areaNames = ["Antrim", "Down", "Tyrone", "Fermanagh", "LondonDerry", "Armagh"];
    const phaseNames = ["REGISTRATION", "VOTING", "FINISHED"];

    let instance, owner, wallets, areas;

    before(async function () {
        wallets = await ethers.getSigners();
        owner = wallets[0];
        const Election = await ethers.getContractFactory("Election");
        instance = await Election.deploy(areaNames);
        await instance.deployed();
    });

    it("Deployment should declare sender as manager and assign all areas", async function() {
        const electionManager = await instance.getElectionManager();

        expect(electionManager).to.equal(owner.address);
    });

    it("Deployment should initialise all areas as passed to constructor", async function() {
        const fetchedAreas = await instance.getAreas();
        const _areaNames = fetchedAreas.map(item => item.name);
        areas = fetchedAreas.map(item => ({
            id: item.id.toNumber(),
            name: item.name
        }));

        expect(_areaNames).to.deep.equal(areaNames);
    });

    it("Registering a voter during registration phase should be accepted", async function() {
        const voterWallet = wallets[1];
        const tx = await instance.connect(voterWallet).registerVoter("Test", "Account", areas[0].id);

        expect(tx).to.be.ok;
    });

    it("Adding a candidate during registration phase should be accepted", async function() {
        const candidateWallet = wallets[2];
        const tx = await instance.connect(candidateWallet).addCandidate("Test", "Candidate", areas[0].id);

        expect(tx).to.be.ok;
    });

    it("Vote should fail during registration phase", async function() {
        const voterWallet = wallets[1];

        try {
            await instance.connect(voterWallet).voteForCandidate(1);
            expect.fail();
        } catch (err) {
            expect(err.message).to.contain("revert");
        }
        
    });

    it("Advancing phase from wallet other than owner should fail", async function() {
        const voterWallet = wallets[1];

        try {
            await instance.connect(voterWallet).advancePhase();
            expect.fail();
        } catch (err) {
            expect(err.message).to.contain("revert");
        }
    });

    it("Advancing phase from owner's wallet should pass and current phase should now be VOTING", async function() {
        await instance.advancePhase();

        const phaseIndex = await instance.getCurrentPhase();
        
        expect(phaseNames[phaseIndex]).to.equal("VOTING");
    });

    it("Voting for candidate should be accepted in VOTING phase", async function() {
        const voterWallet = wallets[1];
        const result = await instance.connect(voterWallet).voteForCandidate(1);

        const transactionReceipt = await result.wait();
        const status = transactionReceipt.status;

        expect(status).to.equal(1);
    });

    it("Voting more than once should fail", async function() {
        const voterWallet = wallets[1];
        
        try {
            await instance.connect(voterWallet).voteForCandidate(1);
            expect.fail();
        } catch (err) {
            expect(err.message).to.contain("revert");
        }
    });

    it("Check candidate vote count is incrementing", async function() {
        const candidate = await instance.getCandidateByID(1);

        expect(candidate.voteCount.toNumber()).to.equal(1);
    });

    it("Declaring Area Winners outside of FINISHED phase should not be accepted", async function() {
        
        try {
            await instance.declareAreaWinners();
            expect.fail();
        } catch (err) {
            expect(err.message).to.contain("revert");
        }
    });

    it("Declare Area Winners during FINISHED phase should be accepted", async function() {
        await instance.advancePhase();
        const tx = await instance.declareAreaWinners();

        expect(tx).to.be.ok;
    });

    it("Area struct should be updated with winning candidate", async function() {
        const _areas = await instance.getAreas();
        const winningCandidates = _areas.map(item => ({
            areaID: item.id.toNumber(),
            candidate: item.candidate,
            name: item.name
        }));

        let antrimWinner;
        for (item of winningCandidates) {
            if (item.name === "Antrim") {
                antrimWinner = item.candidate.user;
            }
        }

        expect(antrimWinner).to.be.equal(wallets[2].address);
    });
});