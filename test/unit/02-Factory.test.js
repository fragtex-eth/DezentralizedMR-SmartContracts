const { expect } = require("chai");
const { network, deployments, ethers, time } = require("hardhat");
const { developmentChains } = require("../../helper-hardhat-config");
const { surveyConfig } = require("../../hardhat-token-config");
const hre = require("hardhat");

!developmentChains.includes(network.name)
  ? describe.skip
  : describe.only("Factory Contract Unit Tests", function () {
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
      });
    });
module.exports.tags = ["all", "token"];
