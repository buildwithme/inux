import { ethers } from "ethers";
import * as fs from "fs";
import * as path from "path";

const NUMBER_OF_ACCOUNTS = 100;
const TEMP_FILE_PATH = path.join(__dirname, "temp-accounts.json");

function generateAccounts() {
  const accounts = [];

  for (let i = 0; i < NUMBER_OF_ACCOUNTS; i++) {
    const wallet = ethers.Wallet.createRandom();
    accounts.push({ privateKey: wallet.privateKey, address: wallet.address });
  }

  fs.writeFileSync(TEMP_FILE_PATH, JSON.stringify(accounts, null, 2));
  console.log(`Generated ${NUMBER_OF_ACCOUNTS} accounts. Details saved to ${TEMP_FILE_PATH}`);
}

generateAccounts();
