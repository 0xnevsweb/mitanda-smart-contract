import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { network } from "hardhat";

interface ChainConfig {
  vrfCoordinator: string;
  gasLane: string;
  callbackGasLimit: string;
  usdcAddress: string;
  subscriptionId: string;
  treasuryWallet: string;
}

const CHAIN_CONFIGS: Record<number, ChainConfig> = {
  84532: {
    vrfCoordinator: process.env.VRF_COORDINATOR || "",
    gasLane: process.env.GAS_LANE || "",
    callbackGasLimit: process.env.CALLBACK_GAS_LIMIT || "",
    usdcAddress: process.env.USDC_ADDRESS || "",
    subscriptionId: process.env.CHAINLINK_SUBSCRIPTION_ID || "",
    treasuryWallet: process.env.TREASURY_WALLET || ""
  },
  8453: {
    vrfCoordinator: process.env.VRF_COORDINATOR || "",
    gasLane: process.env.GAS_LANE || "",
    callbackGasLimit: process.env.CALLBACK_GAS_LIMIT || "",
    usdcAddress: process.env.USDC_ADDRESS || "",
    subscriptionId: process.env.CHAINLINK_SUBSCRIPTION_ID || "",
    treasuryWallet: process.env.TREASURY_WALLET || ""
  }
};

const deployTandaManager: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, ethers } = hre;
  const { deploy, log } = deployments;
  const [deployer] = await ethers.getSigners();
  const chainId: number = network.config.chainId as number;

  if (!chainId) {
    throw new Error("Chain ID is not defined in network configuration");
  }

  const config = CHAIN_CONFIGS[chainId];

  if (!config) {
    throw new Error(`No configuration found for chainId ${chainId}`);
  }

  log("\n=============================================");
  log(`Deploying TandaManager to ${network.name}...`);
  log(`Using deployer: ${deployer.address}`);
  log(`Configuration: ${JSON.stringify(config, null, 2)}`);

  try {
    const deployment = await deploy("TandaManager", {
      from: deployer.address,
      args: [
        config.vrfCoordinator,
        config.subscriptionId,
        config.gasLane,
        config.callbackGasLimit,
        config.usdcAddress,
        config.treasuryWallet
      ],
      log: true,
      waitConfirmations: chainId === 84532 ? 2 : 1, // More confirmations for testnets
    });

    log(`\n✅ TandaManager successfully deployed at: ${deployment.address}`);

    // Skip verification for local networks
    if (chainId !== 31337 && process.env.ETHERSCAN_API_KEY) {
      log("\nStarting contract verification...");
      try {
        await hre.run("verify:verify", {
          address: deployment.address,
          constructorArguments: [
            config.vrfCoordinator,
            BigInt(config.subscriptionId),
            config.gasLane,
            config.callbackGasLimit,
            config.usdcAddress,
            config.treasuryWallet
          ],
        });
        log("\n✅ Contract successfully verified on Etherscan");
      } catch (verificationError) {
        log("\n⚠️ Contract verification failed");
        log(verificationError);
        // Don't exit process for verification failures
      }
    }

  } catch (deploymentError) {
    log("\n❌ TandaManager deployment failed");
    log(deploymentError);
    process.exit(1);
  }

  log("\n=============================================");
};

deployTandaManager.tags = ["all", "tanda-manager"];
export default deployTandaManager;