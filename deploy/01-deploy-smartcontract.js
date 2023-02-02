const { developmentChains } = require("../helper-hardhat-config");
const { verify } = require("../utils/verify");
const { surveyConfig } = require("../hardhat-token-config");
const { network, ethers, upgrades } = require("hardhat");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  args = [
    surveyConfig.questions,
    surveyConfig.maxNumberOfParticipants,
    surveyConfig.endTime,
    surveyConfig.reviewsNeeded,
    surveyConfig.capital,
  ];

  const Survey = await ethers.getContractFactory("SurveyUpgradable");
  const survey = await upgrades.deployProxy(Survey, args);
  await survey.deployed();
  console.log("Survey deployed to: ", survey.address);

  //   if (
  //     !developmentChains.includes(network.name) &&
  //     process.env.ETHERSCAN_API_KEY
  //   ) {
  //     log("Verifying...");
  //     await verify(.address, args);
  //   }
  //   log("----------------------------");
};

module.exports.tags = ["all", "token", "real", "test"];
