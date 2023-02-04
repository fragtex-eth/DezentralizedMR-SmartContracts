const { expect } = require("chai");
const { network, deployments, ethers, time } = require("hardhat");
const { developmentChains } = require("../../helper-hardhat-config");
const { surveyConfig } = require("../../hardhat-token-config");

!developmentChains.includes(network.name)
  ? describe.skip
  : describe("Factory Contract Unit Tests", function () {
      const surveyArgs = [
        surveyConfig.questions,
        surveyConfig.maxNumberOfParticipants,
        surveyConfig.endTime,
        surveyConfig.reviewsNeeded,
        surveyConfig.capital,
      ];
      beforeEach(async () => {
        accounts = await ethers.getSigners();
        deployer = accounts[0];
        alice = accounts[1];
        bob = accounts[2];
        charles = accounts[3];
        await deployments.fixture(["all"]);
        args = [
          surveyConfig.maxNumberOfParticipants,
          surveyConfig.endTime,
          surveyConfig.reviewsNeeded,
          surveyConfig.capital,
        ];
        factoryContract = await ethers.getContract("SurveyFactory");
        //tokenContract = await upgrades.deployProxy(Survey, args);
        tokenContract = await ethers.getContract("Survey");

        factoryContract = factoryContract.connect(deployer);
        factoryContractAlice = factoryContract.connect(alice);
        factoryContractBob = factoryContract.connect(bob);
        factoryContractCharles = factoryContract.connect(charles);
      });
      describe("Stage Test", function () {
        describe("Initalization()", function () {
          it("TokenContract Address gets correctly initialized ", async function () {
            expect(await factoryContract.surveyImplementation()).to.be.equal(
              tokenContract.address
            );
          });
        });
        describe("CreateQuestion()", function () {
          it("Creating a question should not be reverted", async function () {
            await expect(
              factoryContract.createSurvey(
                surveyConfig.questions,
                surveyConfig.maxNumberOfParticipants,
                surveyConfig.endTime,
                surveyConfig.reviewsNeeded,
                surveyConfig.capital,
                {
                  value: surveyConfig.capital,
                }
              )
            ).to.emit(factoryContract, "SurveyCreated");
          });
          it("Should be returned if capital doesn't meet the value", async function () {
            await expect(
              factoryContractAlice.createSurvey(
                surveyConfig.questions,
                surveyConfig.maxNumberOfParticipants,
                surveyConfig.endTime,
                surveyConfig.reviewsNeeded,
                surveyConfig.capital,
                {
                  value: surveyConfig.capital + 1,
                }
              )
            ).to.be.revertedWith(
              "Amount in the message is not equal to the amount specified"
            );
          });
        });
        describe("Surveys running", function () {
          let surveys = [];
          let survey1, survey2, survey3, survey4;
          let survey1Alice;
          beforeEach(async () => {
            /**
             * Create 5 surveys
             */
            for (let i = 0; i < 4; i++) {
              //Not optimal need to find a way to get the address in another way
              survey = await factoryContractAlice.callStatic.createSurvey(
                surveyConfig.questions,
                surveyConfig.maxNumberOfParticipants,
                surveyConfig.endTime,
                surveyConfig.reviewsNeeded,
                surveyConfig.capital + i,
                {
                  value: surveyConfig.capital + i,
                }
              );
              surveys.push(survey);
              survey = await factoryContractAlice.createSurvey(
                surveyConfig.questions,
                surveyConfig.maxNumberOfParticipants,
                surveyConfig.endTime,
                surveyConfig.reviewsNeeded,
                surveyConfig.capital + i,
                {
                  value: surveyConfig.capital + i,
                }
              );
            }

            surveys.push(survey);
            const Survey = await ethers.getContractFactory("Survey");
            survey1 = Survey.attach(surveys[0]);
            survey2 = Survey.attach(surveys[1]);
            survey3 = Survey.attach(surveys[2]);
            survey4 = Survey.attach(surveys[2]);
            survey1Alice = await survey1.connect(alice);
          });
          describe("Events from survey surveys", function () {
            it("Clone correctly initialized", async function () {
              expect(await survey1Alice.owner()).to.equal(
                factoryContract.address
              );
              await expect(survey1Alice.answerQuestions(surveyConfig.answers1))
                .to.not.be.reverted;
            });
            it("Should trigger event in Factory when Clone enters the next stage", async function () {
              //**Answers Survey requested amount -1 times */
              accounts = await ethers.getSigners();
              for (
                var i = 0;
                i < surveyConfig.maxNumberOfParticipants - 1;
                i++
              ) {
                survey1participant = survey1.connect(accounts[i]);
                await survey1participant.answerQuestions(surveyConfig.answers2);
              }
              survey1participant = survey1.connect(
                accounts[surveyConfig.maxNumberOfParticipants]
              );
              await expect(
                survey1participant.answerQuestions(surveyConfig.answers2)
              )
                .to.emit(factoryContract, "SurveyEntersReviewStage")
                .withArgs(survey1.address);

              //**Review Survey requested amount -1 times */
              for (
                var i = 0;
                i <
                surveyConfig.maxNumberOfParticipants *
                  surveyConfig.reviewsNeeded -
                  1;
                i++
              ) {
                let newWallet = ethers.Wallet.createRandom();
                await deployer.sendTransaction({
                  to: newWallet.address,
                  value: ethers.utils.parseEther("1"),
                });
                newWallet = newWallet.connect(ethers.provider);
                newWallet = survey1.connect(newWallet);

                await newWallet.requestReview();
                await newWallet.reviewAnswers(1);
              }
              let newWallet = ethers.Wallet.createRandom();
              await deployer.sendTransaction({
                to: newWallet.address,
                value: ethers.utils.parseEther("1"),
              });
              newWallet = newWallet.connect(ethers.provider);
              newWallet = survey1.connect(newWallet);
              await newWallet.requestReview();
              await expect(newWallet.reviewAnswers(1))
                .to.emit(factoryContract, "SurveyFinished")
                .withArgs(survey1.address);
            });
          });
          describe("Get/Withdraw Earnings", function () {
            beforeEach(async () => {
              //Finish Survey 1:
              //Answering Question Survey1:
              for (
                var i = 5;
                i < surveyConfig.maxNumberOfParticipants + 5 - 1;
                i++
              ) {
                survey1participant = survey1.connect(accounts[i]);
                await survey1participant.answerQuestions(surveyConfig.answers2);
              }
              surveyCharles = survey1.connect(charles);
              await surveyCharles.answerQuestions(surveyConfig.answers3);
              //Completing Review Survey1:
              for (
                var i = 0;
                i <
                surveyConfig.maxNumberOfParticipants *
                  surveyConfig.reviewsNeeded -
                  1;
                i++
              ) {
                let newWallet = ethers.Wallet.createRandom();
                await deployer.sendTransaction({
                  to: newWallet.address,
                  value: ethers.utils.parseEther("1"),
                });
                newWallet = newWallet.connect(ethers.provider);
                newWallet = survey1.connect(newWallet);

                await newWallet.requestReview();
                await newWallet.reviewAnswers(4);
              }
              surveyBob = survey1.connect(bob);
              await surveyBob.requestReview();
              await surveyBob.reviewAnswers(4);
            });
            describe("Withdraw Earnings", function () {
              it("Non participating user should not be able to withdraw", async function () {
                await expect(
                  factoryContractAlice.withdrawEarnings()
                ).to.be.revertedWith("No pending earnings");
              });
              it("Participating user should be able to withdraw", async function () {
                let wallet1balance = await ethers.provider.getBalance(
                  charles.address
                );
                await factoryContractCharles.withdrawEarnings();
                let wallet1balanceAfter = await ethers.provider.getBalance(
                  charles.address
                );
                //Improve make accurate calculation
                expect(parseInt(wallet1balanceAfter)).to.be.greaterThan(
                  parseInt(wallet1balance)
                );
              });
              it("Reviewing user should be able to withdraw", async function () {
                let wallet1balance1 = await ethers.provider.getBalance(
                  bob.address
                );
                await factoryContractBob.withdrawEarnings();
                let wallet1balanceAfter1 = await ethers.provider.getBalance(
                  bob.address
                );
                //Improve make accurate calculation
                expect(parseInt(wallet1balanceAfter1)).to.be.greaterThan(
                  parseInt(wallet1balance1)
                );
              });
              it("User is not able to withdraw twice", async function () {
                await factoryContractBob.withdrawEarnings();
                await expect(
                  factoryContractBob.withdrawEarnings()
                ).to.be.revertedWith("No pending earnings");
              });
            });
          });
        });
      });
    });
module.exports.tags = ["all", "token"];
