const { BigNumber } = require("ethers");
async function main() {
  const MyErcToken = await ethers.getContractFactory("ERCToken");
  const initialSupply = BigNumber.from(10000000);
  const myToken = await MyErcToken.deploy(initialSupply);
  await myToken.deployed();

  console.log("MyErcToken contract  deployed to:", myToken.address);


  const Vesting = await hre.ethers.getContractFactory("LinearVesting");
  const vesting = await Vesting.deploy(myToken.address,2 * 2629743,22 * 2629743);

  await vesting.deployed();

  console.log("Vesting contract deployed to:", vesting.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
