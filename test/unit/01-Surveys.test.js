const { expect } = require("chai");
const { network, deployments, ethers, time } = require("hardhat");
const { developmentChains } = require("../../helper-hardhat-config");
const { surveyConfig } = require("../../hardhat-token-config");

!developmentChains.includes(network.name)
  ? describe.skip
  : describe("Token Unit Tests", function () {
      beforeEach(async () => {
        accounts = await ethers.getSigners();
        deployer = accounts[0];
        alice = accounts[1];
        bob = accounts[2];
        charles = accounts[3];
        await deployments.fixture(["all"]);

        tokenContract = await ethers.getContract("Survey");
        tokenContract = tokenContract.connect(deployer);
        tokenContractAlice = tokenContract.connect(alice);
        tokenContractBob = tokenContract.connect(bob);
        tokenContractCharles = tokenContract.connect(charles);
      });
      describe("Survey Test", function () {
        describe("Initalization()", function () {
          it(
            "Maximum number of particpants should be " +
              surveyConfig.maxNumberOfParticipants,
            async function () {
              expect(await tokenContract.maxNumberOfParticipants()).to.equal(
                surveyConfig.maxNumberOfParticipants
              );
            }
          );
          it("The 5 questions should be initialized correctly", async function () {
            for (let i = 0; i < 5; i++) {
              expect(await tokenContract.questions([i])).to.equal(
                surveyConfig.questions[i]
              );
            }
          });
          it("End Time is set correctly", async function () {
            expect(await tokenContract.endTime()).to.equal(
              surveyConfig.endTime
            );
          });
          it("Capital for participants is set correctly", async function () {
            expect(await tokenContract.capitalParticipants()).to.equal(
              (surveyConfig.capital * 30) / 100
            );
          });
          it("Capital for reviewers is set correctly", async function () {
            expect(await tokenContract.capitalReview()).to.equal(
              (surveyConfig.capital * 70) / 100
            );
          });
        });
        describe("Answer Stage", function () {
          describe("Answer question", function () {
            it("Answer should not be returned when everything is included", async function () {
              await expect(
                tokenContractAlice.answerQuestions(
                  surveyConfig.answers1,
                  alice.address
                )
              ).to.not.be.reverted;
            });
            it("Should be reverted with participant already answered the question", async function () {
              await expect(
                tokenContractAlice.answerQuestions(
                  surveyConfig.answers1,
                  alice.address
                )
              ).to.not.be.reverted;
            });
          });
        });
      });
    });
module.exports.tags = ["all", "token"];
