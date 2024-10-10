import { ethers, run, upgrades } from "hardhat";


async function main() {
    const [deployer] = await ethers.getSigners();
    const bicToken = await ethers.getContractAt("IERC20", ethers.ZeroAddress)
    const HandlesControllerV2 = await ethers.getContractFactory("HandlesControllerV2");
    const updateTx = await upgrades.upgradeProxy("0xdB037d70a593C415CDB6da5bb9F166Ab1eE9F4cb", HandlesControllerV2);
    console.log("🚀 ~ main ~ updateTx:", updateTx.target)
  
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});