import * as dotenv from "dotenv";
dotenv.config();
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-deploy";
import "@matterlabs/hardhat-zksync-solc";
import "@matterlabs/hardhat-zksync-verify";
import * as fs from "fs";
import * as path from "path";
import { HardhatNetworkAccountsUserConfig } from "hardhat/types";

// import "@tenderly/hardhat-tenderly"; // This actually blocks deployments as can't check

// If not set, it uses ours Alchemy's default API key.
// You can get your own at https://dashboard.alchemyapi.io
const providerApiKey = process.env.ALCHEMY_API_KEY || "oKxs-03sij-U_N0iOlrSsZFr29-IqbuF";
// If not set, it uses the hardhat account 0 private key.
const deployerPrivateKey =
  process.env.DEPLOYER_PRIVATE_KEY ?? "...";
// If not set, it uses ours Etherscan default API key.
const etherscanApiKey = process.env.ETHERSCAN_API_KEY || "...";

// get accounts function
function getAccounts(filename: string) {
  const TEMP_FILE_PATH = path.join(__dirname, `./wallets/${filename}.json`);

  let additionalAccounts: string[] = [];

  if (fs.existsSync(TEMP_FILE_PATH)) {
    console.log("TEMP_FILE_PATH", TEMP_FILE_PATH);

    const accountsFile = fs.readFileSync(TEMP_FILE_PATH, "utf8");
    additionalAccounts = JSON.parse(accountsFile).map((acc: any) => acc.privateKey);

    // console.log("additionalAccounts", additionalAccounts);
  }

  return [deployerPrivateKey, ...additionalAccounts];
}
function getAccountsHardhat(filename: string): HardhatNetworkAccountsUserConfig {
  const TEMP_FILE_PATH = path.join(__dirname, `./wallets/${filename}.json`);
  let accounts: { privateKey: string; balance: string }[] = [];

  if (fs.existsSync(TEMP_FILE_PATH)) {
    console.log("TEMP_FILE_PATH", TEMP_FILE_PATH);

    const accountsFile = fs.readFileSync(TEMP_FILE_PATH, "utf8");
    const privateKeys: string[] = JSON.parse(accountsFile).map((acc: any) => acc.privateKey);

    accounts = privateKeys.map(key => ({
      privateKey: key,
      balance: "10000000000000000000000", // Example balance (in wei)
    }));
  }

  accounts = [
    {
      privateKey: deployerPrivateKey,
      balance: "10000000000000000000000", // Example balance (in wei)
    },
    ...accounts,
  ];

  // console.log("accounts", accounts);

  return accounts;
}
const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.20",
    // version: "0.7.6",
    settings: {
      optimizer: {
        enabled: true,
        // https://docs.soliditylang.org/en/latest/using-the-compiler.html#optimizer-options
        runs: 200,
      },
    },
    compilers: [
      {
        version: "0.8.20",
        settings: {
          optimizer: {
            enabled: true,
            // https://docs.soliditylang.org/en/latest/using-the-compiler.html#optimizer-options
            runs: 200,
          },
        },
      },
      {
        version: "0.7.6",
        settings: {
          optimizer: {
            enabled: true,
            // https://docs.soliditylang.org/en/latest/using-the-compiler.html#optimizer-options
            runs: 200,
          },
        },
      },
      {
        version: "0.8.13",
        settings: {
          optimizer: {
            enabled: true,
            // https://docs.soliditylang.org/en/latest/using-the-compiler.html#optimizer-options
            runs: 200,
          },
        },
      },
      {
        version: "0.4.18",
        settings: {
          optimizer: {
            enabled: true,
            // https://docs.soliditylang.org/en/latest/using-the-compiler.html#optimizer-options
            runs: 200,
          },
        },
      },
      // You can add more versions as needed
    ],
  },
  defaultNetwork: "localhost",
  namedAccounts: {
    deployer: {
      // By default, it will take the first Hardhat account as the deployer
      default: 0,
    },
  },
  etherscan: {
    apiKey: "...",
  },
  networks: {
    // View the networks that are pre-configured.
    // If the network you are looking for is not here you can add new network settings
    hardhat: {
      chainId: 31337,
      forking: {
        url: `https://arbitrum-mainnet.infura.io/v3/4c82db4630694c6aafa51f2b4e507abf`,
        enabled: process.env.MAINNET_FORKING_ENABLED === "true",
      },
      accounts: getAccountsHardhat("arbitrum"),
    },
    mainnet: {
      url: `https://eth-mainnet.alchemyapi.io/v2/${providerApiKey}`,
      accounts: getAccounts("mainnet"),
    },
    arbitrum: {
      url: `https://arb-mainnet.g.alchemy.com/v2/${providerApiKey}`,
      accounts: getAccounts("arbitrum"),
    },
    arbitrumGoerli: {
      url: `https://arb-goerli.g.alchemy.com/v2/${providerApiKey}`,
      accounts: getAccounts("arbitrumGoerli"),
    },
    arbitrumSepolia: {
      url: `https://arb-sepolia.g.alchemy.com/v2/${providerApiKey}`,
      accounts: getAccounts("arbitrumSepolia"),
    },
  },
  verify: {
    etherscan: {
      apiKey: "...",
      // `${etherscanApiKey}`,
    },
  },
};

export default config;
