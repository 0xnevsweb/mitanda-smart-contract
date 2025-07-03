import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { network } from "hardhat";

const deployUSDCMock: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, ethers } = hre;
    const { deploy, log } = deployments;
    const [deployer] = await ethers.getSigners();
    const chainId: number = network.config.chainId as number;

    log("\n=============================================");
    log(`Deploying USDCMock to ${network.name}...`);
    log(`Using deployer: ${deployer.address}`);

    try {
        const deployment = await deploy("USDCMock", {
            from: deployer.address,
            args: [],
            log: true,
            waitConfirmations: chainId === 84532 ? 1 : 2,
        });

        log(`\n✅ USDCMock deployed at: ${deployment.address}`);

        if (chainId !== 84532 && process.env.ETHERSCAN_API_KEY) {
            log("\nStarting contract verification...");
            try {
                await hre.run("verify:verify", {
                    address: deployment.address,
                    constructorArguments: [],
                });
                log("✅ Contract successfully verified");
            } catch (err) {
                log("⚠️ Verification failed:");
                log(err);
            }
        }

    } catch (err) {
        log("\n❌ USDCMock deployment failed");
        log(err);
        process.exit(1);
    }

    log("=============================================\n");
};

deployUSDCMock.tags = ["usdc", "mock"];
export default deployUSDCMock;
