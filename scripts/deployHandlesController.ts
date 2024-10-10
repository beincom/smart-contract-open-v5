import { ethers, run, upgrades } from "hardhat";
import { keccak256, toUtf8Bytes } from "ethers";


async function main() {


    const [deployer] = await ethers.getSigners();
    const bicToken = await ethers.getContractAt("IERC20", ethers.ZeroAddress)
    const HandlesController = await ethers.getContractFactory("HandlesController");
    const handlesControllerProxy = await upgrades.deployProxy(HandlesController, [bicToken.target, deployer.address], {
        initializer: "initialize",
        kind: 'uups'
    });
    console.log("🚀 ~ main ~ handlesControllerProxy:", handlesControllerProxy.target)
    await handlesControllerProxy.waitForDeployment();


    try {
        await run("verify:verify", {
            address: handlesControllerProxy.target,
            constructorArguments: [],
        });
    } catch (error) {

    }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});