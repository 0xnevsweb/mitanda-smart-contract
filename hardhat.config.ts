import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-verify";
import "hardhat-deploy";
import "dotenv/config";
import { HardhatUserConfig } from "hardhat/config";

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.20",
        settings: { optimizer: { enabled: true, runs: 200 } }
      },
      {
        version: "0.8.19",
        settings: { optimizer: { enabled: true, runs: 200 } }
      }
    ],
    overrides: {
      "node_modules/@chainlink/contracts/src/v0.8/vrf/dev/VRFCoordinatorV2_5.sol": {
        version: "0.8.19",
        settings: { optimizer: { enabled: true, runs: 200 } }
      }
    }
  },
  networks: {
    localhost: {
      chainId: 31337, // Explicitly set chainId
      allowUnlimitedContractSize: true, // Useful for large contracts
      mining: {
        auto: true, // Auto-mining enabled by default
        interval: 5000 // Optional: mine a block every 5 seconds
      }
    },
    baseSepolia: {
      url: process.env.BASE_SEPOLIA_RPC_URL || "",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 84532,
      verify: {
        etherscan: {
          apiUrl: "https://api-sepolia.basescan.org"
        }
      }
    },
    baseMainnet: {
      url: process.env.BASE_MAINNET_RPC_URL || "",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 8453,
      verify: {
        etherscan: {
          apiUrl: "https://api.basescan.org"
        }
      }
    },
  },
  etherscan: {
    apiKey: {
      baseSepolia: process.env.ETHERSCAN_API_KEY || "",
      baseMainnet: process.env.ETHERSCAN_API_KEY || "",
    },
    customChains: [
      {
        network: "baseSepolia",
        chainId: 84532,
        urls: {
          apiURL: "https://api-sepolia.basescan.org/api",
          browserURL: "https://sepolia.basescan.org"
        }
      },
      {
        network: "baseMainnet",
        chainId: 8453,
        urls: {
          apiURL: "https://api.basescan.org/api",
          browserURL: "https://basescan.org"
        }
      }
    ]
  },
  mocha: {
    timeout: 200000,
  },
  paths: {
    deploy: ["scripts"],
  },
};

export default config;