import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";

/**
 * Deploys a contract named "InuX" using the deployer account and
 * constructor arguments set to the deployer address
 *
 * @param hre HardhatRuntimeEnvironment object.
 */
const deployInuX: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  /*
    On localhost, the deployer account is the one that comes with Hardhat, which is already funded.

    When deploying to live networks (e.g `yarn deploy --network goerli`), the deployer account
    should have sufficient balance to pay for the gas fees for contract creation.

    You can generate a random account with `yarn generate` which will fill DEPLOYER_PRIVATE_KEY
    with a random private key in the .env file (then used on hardhat.config.ts)
    You can run the `yarn account` command to check your balance in every network.
  */

  const [owner] = await ethers.getSigners();
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;

  console.log("owner", await ethers.getSigners());
  console.log("deployer", deployer);

  const isLocalhost = hre.network.name === "localhost" || hre.network.name === "hardhat";
  console.log("hre.network.name", hre.network.name);

  const canDeploy = false;
  const canAddFunds = false;
  const canCreatePool = false && isLocalhost;

  const wrapped_native_tokens = "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1"; // WETH arbitrum
  const nonfungiblePositionManager = "0xC36442b4a4522E871399CD717aBDD847Ab11FE88"; // non fungible position manager arbitrum
  const uniswapFactoryAddress = "0x1F98431c8aD98523631AE4a59f267346ea31F984"; // uniswap factory address arbitrum

  if (canDeploy) {
    const futureInuXAddress = await getCorrectInuXAddress(deployer, owner, wrapped_native_tokens);
    console.log("futureInuXAddress", futureInuXAddress);

    const futureInuXVaultAddress = await predictContractAddress(deployer, 1);
    console.log("futureInuXVaultAddress", futureInuXVaultAddress);

    const deployedInuX = await deploy("InuX", {
      from: deployer,
      args: [futureInuXVaultAddress],
      log: true,
      autoMine: true,
    });
    console.log("deployedInuX", deployedInuX.address);

    const deployedInuXVault = await deploy("InuXVault", {
      from: deployer,
      args: [nonfungiblePositionManager, uniswapFactoryAddress, wrapped_native_tokens, deployedInuX.address],
      log: true,
      autoMine: true,
    });

    console.log("deployedInuXVault", deployedInuXVault.address);
  }

  const InuXVault = await ethers.getContractAt("InuXVault", "0x70358e35957f16b818588a3CFA57cc73d7D126c3");

  if (canAddFunds) {
    await sendEther({
      [InuXVault.address]: "0.0045",
    });
  }

  if (canCreatePool) {
    // create a new block
    console.log("Calling createPoolAndAddInitialLiquidity");
    const tx = await InuXVault.createPoolAndAddLiquidity();
    await tx.wait();
  }
};

async function predictContractAddress(deployerAddress: string, nonceOffset = 0) {
  const nonce = (await ethers.provider.getTransactionCount(deployerAddress)) + nonceOffset;
  const predictedAddress = ethers.utils.getContractAddress({
    from: deployerAddress,
    nonce: nonce,
  });

  return predictedAddress;
}

async function sendEther(transfers) {
  const [owner] = await ethers.getSigners();
  console.log("Owner address:", owner.address);

  for (const [address, amount] of Object.entries(transfers)) {
    console.log(`Preparing to send ${amount} ETH to ${address} from %s`, owner.address);

    // Parse the amount to the correct format
    const parsedAmount = ethers.utils.parseEther(amount);

    const tx = await owner.sendTransaction({
      to: address,
      value: parsedAmount,
    });

    // Wait for the transaction to be mined
    await tx.wait();
  }

  console.log("Finished sending ETH.");
}

async function getCorrectInuXAddress(deployer, owner, WETH_ADDRESS) {
  let futureInuXAddress = await predictContractAddress(deployer);
  console.log("futureInuXAddress", futureInuXAddress);

  // i have to iterate over this future address until it's greater than WETH_ADDRESS
  // most probably i need to make a transaction every time in order to increase the nonce
  // we can do this by sending 0 eth to the deployer
  while (!sortAndCheckFirstAddress([WETH_ADDRESS, futureInuXAddress], WETH_ADDRESS)) {
    console.log("%s is less than %s", futureInuXAddress, WETH_ADDRESS);

    const tx = await owner.sendTransaction({
      to: owner.address,
      value: ethers.utils.parseEther("0"),
    });
    await tx.wait();

    futureInuXAddress = await predictContractAddress(deployer);
    console.log("futureInuXAddress", futureInuXAddress);
  }

  if (futureInuXAddress > WETH_ADDRESS) {
    console.log("%s is greater than %s", futureInuXAddress, WETH_ADDRESS);
  }

  return futureInuXAddress;
}
function sortAndCheckFirstAddress(addresses, specificAddress) {
  // Sort the addresses
  const sortedAddresses = addresses.sort((a, b) => {
    if (a.toLowerCase() < b.toLowerCase()) return -1;
    if (a.toLowerCase() > b.toLowerCase()) return 1;
    return 0;
  });

  // Check if the first address is the specific address
  const isFirstAddressSpecific = sortedAddresses[0].toLowerCase() === specificAddress.toLowerCase();

  return isFirstAddressSpecific;
}

export default deployInuX;

// Tags are useful if you have multiple deploy files and only want to run one of them.
// e.g. yarn deploy --tags InuX
deployInuX.tags = ["token"];
