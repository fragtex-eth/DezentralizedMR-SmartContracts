const { network } = require("hardhat");
const { developmentChains } = require("../helper-hardhat-config");
const { verify } = require("../utils/verify");
const { surveyConfig } = require("../hardhat-token-config");

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

  const token = await deploy("Survey", {
    from: deployer,
    args: args,
    log: true,
    waitConfirmations: network.config.waitConfirmations || 1,
  });

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
