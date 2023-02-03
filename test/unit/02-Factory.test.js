const { expect } = require("chai");
const { network, deployments, ethers, time } = require("hardhat");
const { developmentChains } = require("../../helper-hardhat-config");
const { surveyConfig } = require("../../hardhat-token-config");
const hre = require("hardhat");

!developmentChains.includes(network.name)
  ? describe.skip
  : describe.only("Factory Contract Unit Tests", function () {
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
        args = [
          surveyConfig.maxNumberOfParticipants,
          surveyConfig.endTime,
          surveyConfig.reviewsNeeded,
          surveyConfig.capital,
        ];
        const Survey = await ethers.getContractFactory("SurveyUpgradable");
        tokenContract = await upgrades.deployProxy(Survey, args);
        const Factory = await ethers.getContractFactory("SurveyFactory");
        factoryContract = await Factory.deploy(tokenContract.address);
        await factoryContract.deployed();

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
          let survey1Alice;
          beforeEach(async () => {
            /**
             * Create 5 surveys
             */
            for (let i = 0; i < 4; i++) {
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
            }
            survey = await factoryContractBob.callStatic.createSurvey(
              surveyConfig.questions,
              surveyConfig.maxNumberOfParticipants,
              surveyConfig.endTime,
              surveyConfig.reviewsNeeded,
              surveyConfig.capital + 100,
              {
                value: surveyConfig.capital + 100,
              }
            );
            surveys.push(survey);
            const Survey = await ethers.getContractFactory("SurveyUpgradable");
            survey1 = Survey.attach(surveys[0]);
            survey1Alice = await survey1.connect(alice);
          });
          describe("Events from survey surveys", function () {
            it("should trigger even when answering a survey", async function () {
              await expect(survey1Alice.answerQuestions(surveyConfig.answers1))
                .to.not.be.reverted;
              await expect(survey1Alice.factoryC()).to.be.revertedWith("23");
              //   expect(
              //     await factoryContractBob.surveyParticpated(alice.address)
              //   ).to.be.equal(surveys[0]);
            });
          });
        });
      });
    });
module.exports.tags = ["all", "token"];
