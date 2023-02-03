// const { expect } = require("chai");
// const { network, deployments, ethers, time } = require("hardhat");
// const { developmentChains } = require("../../helper-hardhat-config");
// const { surveyConfig } = require("../../hardhat-token-config");

// !developmentChains.includes(network.name)
//   ? describe.skip
//   : describe("Token Unit Tests", function () {
//       beforeEach(async () => {
//         accounts = await ethers.getSigners();
//         deployer = accounts[0];
//         alice = accounts[1];
//         bob = accounts[2];
//         charles = accounts[3];
//         args = [
//           surveyConfig.maxNumberOfParticipants,
//           surveyConfig.endTime,
//           surveyConfig.reviewsNeeded,
//           surveyConfig.capital,
//         ];
//         Survey = await await ethers.getContractFactory("SurveyUpgradable");
//         tokenContract = await upgrades.deployProxy(Survey, args);

//         tokenContract = tokenContract.connect(deployer);
//         tokenContractAlice = tokenContract.connect(alice);
//         tokenContractBob = tokenContract.connect(bob);
//         tokenContractCharles = tokenContract.connect(charles);
//         await tokenContract.setQuestions(surveyConfig.questions);
//       });
//       describe("Stage Test", function () {
//         describe("Initalization()", function () {});
//       });
//     });
// module.exports.tags = ["all", "token"];
