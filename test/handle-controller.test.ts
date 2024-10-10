import { expect } from "chai";
import { Wallet } from "ethers";
import { ethers, upgrades } from "hardhat";



describe("HandleController upgradeable", async function () {
    let proxyAddress: string;
    before(async () => {
        const [deployer] = await ethers.getSigners();
        const bicToken = await ethers.getContractAt("IERC20", ethers.ZeroAddress);
        const HandlesController = await ethers.getContractFactory("HandlesController");

        
        const proxy = await upgrades.deployProxy(HandlesController, [bicToken.target, deployer.address], {
            initializer: "initialize",
            kind: 'uups'
        });
        await proxy.waitForDeployment();
        proxyAddress = proxy.target as string;
    });

    it('Should read contract successfully', async () => {
        const proxy = await ethers.getContractAt("HandlesController", proxyAddress);
        const verifierPrev = await proxy.verifier();
        const marketplace = await proxy.marketplace();
        // expect(verifierPrev).to.be.equal(ethers.ZeroAddress);

        const randomWallet = Wallet.createRandom();
        console.log("🚀 ~ it ~ randomWallet:", randomWallet.address)

        const setVerifierTx = await proxy.setVerifier(randomWallet.address);
        await setVerifierTx.wait();

        const verifierNext = await proxy.verifier();
        expect(verifierNext).to.be.equal(randomWallet.address);


        // const proxyV2 = await ethers.getContractAt("HandlesControllerV2", proxyAddress);
        // Should be failed because the function is not exist in HandlesController
        // const countPrev = await proxyV2.greet();
        // await expect(countPrev).to.be.revertedWith("Error: Transaction reverted: function selector was not recognized and there's no fallback function");
    });

    it('Upgradeable contract', async () => {
        const [deployer] = await ethers.getSigners();
        const HandleControllerV2 = await ethers.getContractFactory("HandlesControllerV2");

        const upgradeTx = await upgrades.upgradeProxy(proxyAddress, HandleControllerV2);
        await upgradeTx.waitForDeployment();

        const proxyV2 = await ethers.getContractAt("HandlesControllerV2", proxyAddress);

        const countPrev = await proxyV2.greeting(deployer.address);
        expect(countPrev).to.be.equal(0n);


        const greetTx = await proxyV2.greet();
        await greetTx.wait();


        const countNext = await proxyV2.greeting(deployer.address);
        expect(countNext).to.be.equal(countPrev + 1n);
        
    });


});