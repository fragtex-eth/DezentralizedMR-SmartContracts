const { expect } = require("chai");
const { network, deployments, ethers, time } = require("hardhat");
const { developmentChains } = require("../../helper-hardhat-config");
const helpers = require("@nomicfoundation/hardhat-network-helpers");

!developmentChains.includes(network.name)
  ? describe.skip
  : describe("Token Unit Tests", function () {
      beforeEach(async () => {
        accounts = await ethers.getSigners();
        deployer = accounts[0];
        alice = accounts[1];
        bob = accounts[2];
        charles = accounts[3];
        team = accounts[4];
        await deployments.fixture(["all"]);

        tokenContract = await ethers.getContract("Encircled");
        tokenContractUSD = await ethers.getContract("BEP20USDT");
        tokenContractVesting = await ethers.getContract("EncdVesting");
        tokenContractICO = await ethers.getContract("ENCD_ICOT");

        tokenContract = tokenContract.connect(deployer);

        tokenContractICO = tokenContractICO.connect(deployer);
        tokenContractICOAlice = tokenContractICO.connect(alice);
        tokenContractICOBob = tokenContractICO.connect(bob);
        tokenContractICOCharles = tokenContractICO.connect(charles);

        tokenContractUSDT = tokenContractUSD.connect(deployer);
        tokenContractUSDTAlice = tokenContractUSD.connect(alice);
        tokenContractUSDTBob = tokenContractUSD.connect(bob);
        tokenContractUSDTCharles = tokenContractUSD.connect(charles);

        tokenContractVesting = tokenContractVesting.connect(deployer);
        tokenContractVestingAlice = tokenContractVesting.connect(alice);
        tokenContractVestingBob = tokenContractVesting.connect(bob);
        tokenContractVestingCharles = tokenContractVesting.connect(charles);
      });
      describe("Contract & Test set up", function () {
        beforeEach(async () => {
          //Set up contracts
          //Make ICOContract owner of Vesting Contract
          tokenContractVesting.transferOwnership(tokenContractICO.address);
          //Exclude Vesting Contract from Paying and Receiving Fees
          await tokenContract.excludeFromFee(tokenContractVesting.address);
          await tokenContract.excludeFromReward(tokenContractVesting.address);

          //Transfer all vested tokens to the vesting contract
          await tokenContract.transfer(
            tokenContractVesting.address,
            ethers.utils.parseUnits("190000000", 18) //Team + Presale
          );
          //Transfer the rest to the selected addresses
          await tokenContract.transfer(
            "0xbA31CF23ffDff8ADaD7C035551F140239F2F0514",
            ethers.utils.parseUnits("10000000", 18) //Liquidity
          );

          /**
           * Test set up (Transfer Mock USDT to the different users)
           */
          await tokenContractUSDT.transfer(
            alice.address,
            ethers.utils.parseUnits("1000000000000000", 18)
          );
          await tokenContractUSDT.transfer(
            bob.address,
            ethers.utils.parseUnits("1000000000000000", 18)
          );
          await tokenContractUSDT.transfer(
            charles.address,
            ethers.utils.parseUnits("1000000000000000", 18)
          );
          //All team members approve the ico contract to spend their tokens
          await tokenContractUSDTAlice.approve(
            tokenContractICO.address,
            ethers.utils.parseUnits("10000000000000000000", 18)
          );
          await tokenContractUSDTBob.approve(
            tokenContractICO.address,
            ethers.utils.parseUnits("10000000000000000000", 18)
          );
          await tokenContractUSDTCharles.approve(
            tokenContractICO.address,
            ethers.utils.parseUnits("10000000000000000000", 18)
          );
        });
        it("Cycle 1: Multiple users buy the tokens in the presale", async function () {
          expect(await tokenContract.balanceOf(deployer.address)).to.be.equal(
            0
          );
          //Start TeamSale
          await tokenContractICO.startVesting(60 * 60 * 24 * 30); //Set token start launch = 30 days
          //Presale starts
          await tokenContractICO.setStage(1); //Duration 60*60*24*300 days

          //Charles buys half of the available tokens
          await tokenContractICOCharles.buyToken(
            ethers.utils.parseUnits("8000000", 18),
            1
          ); //costs 160000USDT

          //Bob trys to buy the all available tokens
          await expect(
            tokenContractICOBob.buyToken(
              ethers.utils.parseUnits("9000000", 18),
              1
            )
          ).to.be.revertedWith(
            "Not enough tokens left for purchase in this stage"
          ); //costs 160000USDT

          await expect(
            tokenContractICOBob.buyToken(
              ethers.utils.parseUnits("8000000", 18),
              1
            )
          ).not.to.be.reverted;

          await expect(tokenContractICOAlice.buyToken(1, 1)).to.be.revertedWith(
            "All tokens in this stage sold, wait for the next stage"
          );

          //No Tokens should be available to withdraw since sale hasn't started yet
          const vestingScheduleCharles =
            await tokenContractVesting.computeVestingScheduleIdForAddressAndIndex(
              charles.address,
              0
            );
          const vestingScheduleBob =
            await tokenContractVesting.computeVestingScheduleIdForAddressAndIndex(
              bob.address,
              0
            );
          expect(
            await tokenContractVesting.computeReleasableAmount(
              vestingScheduleCharles
            )
          ).to.be.equal(0);
          expect(
            await tokenContractVesting.computeReleasableAmount(
              vestingScheduleBob
            )
          ).to.be.equal(0);

          //Expect contract usdt amount to be equal to 320k
          let Balance1 = await tokenContractUSDT.balanceOf(
            tokenContractICO.address
          );
          expect(Balance1).to.be.equal(ethers.utils.parseUnits("320000", 18));
          //Owner withdraws 20k
          await tokenContractICO.withdraw(
            ethers.utils.parseUnits("200000", 18),
            1
          );
          let Balance2 = await tokenContractUSDT.balanceOf(
            tokenContractICO.address
          );
          expect(Balance2).to.be.equal(ethers.utils.parseUnits("120000", 18));

          await helpers.time.increase(60 * 60 * 24 * 10);
          await tokenContractICO.setStage(2);

          //Alice decides to buy the total stage 2 tokens
          await tokenContractICOAlice.buyToken(
            ethers.utils.parseUnits("30000000", 18),
            1
          ); //Costs = 1,200,000 USD
          //Charles wants to buy another token but not enough left gets returned
          await expect(
            tokenContractICOCharles.buyToken(1, 1)
          ).to.be.revertedWith(
            "All tokens in this stage sold, wait for the next stage"
          );

          //Test at end of the stage
          expect(
            await tokenContractVesting.computeReleasableAmount(
              vestingScheduleCharles
            )
          ).to.be.equal(0);
          expect(
            await tokenContractVesting.computeReleasableAmount(
              vestingScheduleBob
            )
          ).to.be.equal(0);

          //Expect contract usdt amount to be equal to 120k + 1,2M => 1 320 000
          Balance1 = await tokenContractUSDT.balanceOf(
            tokenContractICO.address
          );
          expect(Balance1).to.be.equal(ethers.utils.parseUnits("1320000", 18));

          await helpers.time.increase(60 * 60 * 24 * 10);
          await tokenContractICO.setStage(3);

          //Alice decides to buy more tokens
          await tokenContractICOAlice.buyToken(
            ethers.utils.parseUnits("10000000", 18),
            1
          ); //Costs = 800,000 USD
          await expect(
            tokenContractICOBob.buyToken(
              ethers.utils.parseUnits("11213000", 18),
              1
            )
          ).to.be.revertedWith(
            "Not enough tokens left for purchase in this stage"
          );
          await tokenContractICOCharles.buyToken(
            ethers.utils.parseUnits("10000000", 18),
            1
          ); //Costs = 800,000 USD
          await expect(
            tokenContractICOBob.buyToken(ethers.utils.parseUnits("1", 18), 1)
          ).to.be.revertedWith("All tokens sold");

          expect(
            await tokenContractVesting.computeReleasableAmount(
              vestingScheduleCharles
            )
          ).to.be.equal(0);
          expect(
            await tokenContractVesting.computeReleasableAmount(
              vestingScheduleBob
            )
          ).to.be.equal(0);

          //Expect contract usdt amount to be equal to 1320000 + 800k + 800k = 2.92M
          Balance1 = await tokenContractUSDT.balanceOf(
            tokenContractICO.address
          );
          expect(Balance1).to.be.equal(ethers.utils.parseUnits("2920000", 18));
          //Owner withdraws 20k
          await tokenContractICO.withdraw(
            ethers.utils.parseUnits("2920000", 18),
            1
          );
          Balance2 = await tokenContractUSDT.balanceOf(
            tokenContractICO.address
          );
          expect(Balance2).to.be.equal(ethers.utils.parseUnits("0", 18));

          await helpers.time.increase(60 * 60 * 24 * 10); //End of Presale all tokens have been sold

          expect(
            await tokenContractVesting.computeReleasableAmount(
              vestingScheduleCharles
            )
          ).to.be.equal(ethers.utils.parseUnits("500000", 18)); //TGE: 6.25% = 500000
          expect(
            await tokenContractVesting.computeReleasableAmount(
              vestingScheduleBob
            )
          ).to.be.equal(ethers.utils.parseUnits("500000", 18)); //TGE: 6.25% = 500000
          const vestingScheduleAlice =
            await tokenContractVesting.computeVestingScheduleIdForAddressAndIndex(
              alice.address,
              0
            );
          expect(
            await tokenContractVesting.computeReleasableAmount(
              vestingScheduleAlice
            )
          ).to.be.equal(ethers.utils.parseUnits("3750000", 18)); //TGE: 12.5% = 3.75M
          const vestingScheduleAlice1 =
            await tokenContractVesting.computeVestingScheduleIdForAddressAndIndex(
              alice.address,
              1
            );
          expect(
            await tokenContractVesting.computeReleasableAmount(
              vestingScheduleAlice1
            )
          ).to.be.equal(ethers.utils.parseUnits("2500000", 18)); //TGE: 25% * 10000000
          await tokenContractVestingAlice.release(
            vestingScheduleAlice,
            ethers.utils.parseUnits("1000000", 18)
          );
          await tokenContractVestingBob.release(
            vestingScheduleBob,
            ethers.utils.parseUnits("100000", 18)
          );

          expect(
            await tokenContractVesting.computeReleasableAmount(
              vestingScheduleAlice
            )
          ).to.be.equal(ethers.utils.parseUnits("2750000", 18));

          await helpers.time.increase(60 * 60 * 24);

          expect(
            await tokenContractVesting.computeReleasableAmount(
              vestingScheduleBob
            )
          ).to.be.equal("420833333333333333333333");

          await helpers.time.increase(60 * 60 * 24 * 10 * 100 * 1000000);
          //Team Wallets
          let justin =
            await tokenContractVesting.computeVestingScheduleIdForAddressAndIndex(
              "0x02346e9d0173ce68237330cf8305025f2a54520c",
              0
            );
          let kenda =
            await tokenContractVesting.computeVestingScheduleIdForAddressAndIndex(
              "0x5f50fe907829c957ff3db0555dce07729c005618",
              0
            );
          let vaidotas =
            await tokenContractVesting.computeVestingScheduleIdForAddressAndIndex(
              "0x921883944a96a7fdda44588970be8eb58c3f773a",
              0
            );
          let nathan =
            await tokenContractVesting.computeVestingScheduleIdForAddressAndIndex(
              "0xfb87eed8bdcff1494faf79d25ae6034e09111642",
              0
            );
          let vanessa =
            await tokenContractVesting.computeVestingScheduleIdForAddressAndIndex(
              "0x63189ae134bb90e7c1e0dbd5c3f342e95a845737",
              0
            );
          let futuretm =
            await tokenContractVesting.computeVestingScheduleIdForAddressAndIndex(
              "0xead96e2eaca0d0eedcfd0888b4905994ba69d35a",
              0
            );
          let lukas =
            await tokenContractVesting.computeVestingScheduleIdForAddressAndIndex(
              "0xabeda65b89e9decc197f38730af7838134f89aa9",
              0
            );
          let gabrielle =
            await tokenContractVesting.computeVestingScheduleIdForAddressAndIndex(
              "0x6be976ca92d9f3d8500ad02a8497e162ad134231",
              0
            );
          let marketing =
            await tokenContractVesting.computeVestingScheduleIdForAddressAndIndex(
              "0xb157cb8e5caec3ffaf81b96e4120bd7cb5ffb222",
              0
            );
          let reserve =
            await tokenContractVesting.computeVestingScheduleIdForAddressAndIndex(
              "0x9fa96bf3763c53dfac0fe63edfe962adffacd4ce",
              0
            );
          let ecosys =
            await tokenContractVesting.computeVestingScheduleIdForAddressAndIndex(
              "0xe325854cfcc89546d9c9bfcfa32967864287bd0c",
              0
            );
          let rewards =
            await tokenContractVesting.computeVestingScheduleIdForAddressAndIndex(
              "0x2abad5e20594ff4e96e698e1d255f03680a9e4d8",
              0
            );

          expect(
            await tokenContractVesting.computeReleasableAmount(justin)
          ).to.be.equal(ethers.utils.parseUnits("4000000", 18));

          expect(
            await tokenContractVesting.computeReleasableAmount(kenda)
          ).to.be.equal(ethers.utils.parseUnits("4000000", 18));
          expect(
            await tokenContractVesting.computeReleasableAmount(vaidotas)
          ).to.be.equal(ethers.utils.parseUnits("1000000", 18));
          expect(
            await tokenContractVesting.computeReleasableAmount(nathan)
          ).to.be.equal(ethers.utils.parseUnits("2000000", 18));
          expect(
            await tokenContractVesting.computeReleasableAmount(vanessa)
          ).to.be.equal(ethers.utils.parseUnits("2000000", 18));
          expect(
            await tokenContractVesting.computeReleasableAmount(futuretm)
          ).to.be.equal(ethers.utils.parseUnits("7000000", 18));
          //Advisors
          expect(
            await tokenContractVesting.computeReleasableAmount(lukas)
          ).to.be.equal(ethers.utils.parseUnits("5000000", 18));
          expect(
            await tokenContractVesting.computeReleasableAmount(gabrielle)
          ).to.be.equal(ethers.utils.parseUnits("5000000", 18));

          //Marketing
          expect(
            await tokenContractVesting.computeReleasableAmount(rewards)
          ).to.be.equal(ethers.utils.parseUnits("30000000", 18));
          //Reserve
          expect(
            await tokenContractVesting.computeReleasableAmount(marketing)
          ).to.be.equal(ethers.utils.parseUnits("14000000", 18));
          //Ecosystem
          expect(
            await tokenContractVesting.computeReleasableAmount(reserve)
          ).to.be.equal(ethers.utils.parseUnits("20000000", 18));
          //Ecosystem
          expect(
            await tokenContractVesting.computeReleasableAmount(ecosys)
          ).to.be.equal(ethers.utils.parseUnits("30000000", 18));
        });
      });
    });
module.exports.tags = ["all", "vesting"];
