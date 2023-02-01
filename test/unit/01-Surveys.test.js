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
          it("Stage is correctly set", async function () {
            expect(await tokenContract.stage()).to.equal(0);
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
            it("Should be reverted when requirements are not met", async function () {
              await tokenContractAlice.answerQuestions(
                surveyConfig.answers1,
                alice.address
              );
              await expect(
                tokenContractAlice.answerQuestions(
                  surveyConfig.answers1,
                  alice.address
                )
              ).to.be.revertedWith("Already answered");
              await expect(
                tokenContractAlice.answerQuestions(["1", "2", "3"], bob.address)
              ).to.be.revertedWith(
                "Number of answers have to be equal to the number of questions"
              );
              accounts = await ethers.getSigners();
              for (var i = 1; i < surveyConfig.maxNumberOfParticipants; i++) {
                let participant = ethers.Wallet.createRandom();
                tokenContractAlice.answerQuestions(
                  surveyConfig.answers2,
                  participant.address
                );
              }
              let newpart = ethers.Wallet.createRandom();
              await expect(
                tokenContract.answerQuestions(
                  surveyConfig.answers2,
                  newpart.address
                )
              ).to.be.revertedWith("Participant limit reached");
            });
          });
          describe("Locked functions", function () {
            it("Locked functions should be reverted", async function () {
              await expect(tokenContract.viewAnswers(alice.address, 1)).to.be
                .reverted;
              await expect(tokenContract.getValidAnswers()).to.be.reverted;
              await expect(tokenContract.requestReview(alice.address)).to.be
                .reverted;
              await expect(tokenContract.reviewAnswers(alice.address)).to.be
                .reverted;
            });
          });
        });
        describe("Answer Stage", function () {
          beforeEach(async () => {
            //Answer all questions => Enter Stage
            for (var i = 0; i < surveyConfig.maxNumberOfParticipants; i++) {
              let newwallet = ethers.Wallet.createRandom();
              await tokenContract.answerQuestions(
                surveyConfig.answers1,
                newwallet.address
              );
            }
          });
          describe("Initialization of the next stage", function () {
            it("Stage change successful", async function () {
              expect(await tokenContract.stage()).to.equal(1);
            });
          });
          describe("requestReview", function () {
            it("Reviews can requested if all requirements are met", async function () {
              await expect(tokenContractAlice.requestReview(alice.address)).to
                .not.be.reverted;
            });
            it("Reviews can't be requested if already requested", async function () {
              tokenContractAlice.requestReview(alice.address);
              await expect(
                tokenContractAlice.requestReview(alice.address)
              ).to.be.revertedWith("Already assigned");
            });
            it("Participant assigned to reviewee", async function () {
              await tokenContractAlice.requestReview(alice.address);
              const revieweeParticipant =
                await tokenContractAlice.returnReviewParticipant(alice.address);
              expect(tokenContractAlice.returnReviewParticipant(alice.address))
                .to.not.be.reverted;
            });
            it("Able to return answers for the assigned reviewee", async function () {
              await tokenContractAlice.requestReview(alice.address);
              const revieweeParticipant =
                await tokenContractAlice.returnReviewParticipant(alice.address);

              for (let i = 0; i < 5; i++) {
                let answers = await tokenContract.viewAnswers(
                  revieweeParticipant,
                  i
                );
                await expect(answers).to.equal(surveyConfig.answers1[i]);
              }
            });
          });
          describe("reviewAnswers", function () {
            beforeEach(async () => {
              await tokenContractAlice.requestReview(alice.address);
              const revieweeParticipantAlice =
                await tokenContractAlice.returnReviewParticipant(alice.address);
            });
            it("Should not be returned all requirements are met", async function () {
              await expect(tokenContract.reviewAnswers(alice.address, 1)).to.not
                .be.reverted;
            });
            it("should be able to do all reviews", async function () {
              for (
                var i = 0;
                i <
                surveyConfig.maxNumberOfParticipants *
                  surveyConfig.reviewsNeeded;
                i++
              ) {
                let newWallet = ethers.Wallet.createRandom();
                await tokenContract.requestReview(newWallet.address);
                await tokenContract.reviewAnswers(newWallet.address, 1);
              }
            });
          });
        });
      });
    });
module.exports.tags = ["all", "token"];
