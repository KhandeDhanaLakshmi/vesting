const { expect } = require("chai");
const { BigNumber } = require("ethers");
const { ethers } = require("hardhat");

describe("Vesting", function () {
  let DkToken;
  let dkToken;
  let Vesting;
  let vesting;
  let addr1;
  let addr2;
  let addr3;
  let owner;
  let creator;

  beforeEach(async () => {
    [owner, creator, addr1, addr2, addr3] = await ethers.getSigners();
    DkToken = await ethers.getContractFactory("ERCToken");
    const initialSupply = BigNumber.from(10000000);
    dkToken = await DkToken.deploy(initialSupply);
    await dkToken.deployed();
    dkTokenAddress = dkToken.address;

    // For Vesting Contract

    Vesting = await hre.ethers.getContractFactory("LinearVesting");
    vesting = await Vesting.deploy(dkTokenAddress, 2 * 2629743, 22 * 2629743);
    await vesting.deployed();
    vestingAddress = vesting.address;

    await dkToken.transfer(vestingAddress, dkToken.balanceOf(owner.address));

    await vesting.connect(owner).addBeneficiaryRole(addr1.address, 0); //beneficiary for role 0
    await vesting.connect(owner).addBeneficiaryRole(addr2.address, 1); //beneficiary for role 1
    await vesting.connect(owner).addBeneficiaryRole(addr3.address, 2); //beneficiary for role 2
  });

  it("Start the vesting ", async () => {
    await vesting.startVesting();

    expect(await vesting.isVestingStarted()).to.equal(true);
  });

  it("Should not claim tokens in cliff period ", async () => {
    await vesting.startVesting();

    expect(vesting.connect(addr1).claimToken()).to.be.revertedWith(
      "Can't Claim tokens as vesting is in cliff period"
    );
  });

  it("Should claim tokens after cliff period ", async () => {
    await vesting.startVesting();

    await ethers.provider.send("evm_increaseTime", [
      2 * 2629743 + 22 * 2629743,
    ]);
    const balanceBefore = await dkToken.connect(addr1).balanceOf(addr1.address);

    await vesting.connect(addr1).claimToken();

    const balanceAfter = await dkToken
      .connect(addr1)
      .balanceOf(addr1.address);

    expect(balanceBefore).to.be.not.equal(balanceAfter);

    // const vestedAmount = await vesting.getTokensVested(0);

    // expect(vestedAmount).to.be.equals(500000);
  });
});
