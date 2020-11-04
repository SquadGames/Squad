const hre = require("hardhat")
const ethers = hre.ethers

let reserveTokenAddress

const main = async () => {
  await hre.run('compile')
  console.log(hre.ethers, ethers)
  const ReserveToken = await ethers.getContractFactory('ERC20Managed')
  reserveTokenAddress = ReserveToken.address
}

main()
  .then((res) => {
    console.log(res)
    console.log(reserveTokenAddress)
  })
  .catch((res) => {
    console.error(res)
  })