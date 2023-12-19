const hre = require("hardhat");
const fs = require('fs');
const { ethers } = require("hardhat");

async function setProxyAddresses(config,contract_name,contract_address) {
  config[contract_name+"_PROXY_CONTRACT_ADDRESS"] = contract_address;
  config[contract_name+"_CONTRACT_ADDRESS"] = await hre.upgrades.erc1967.getImplementationAddress(contract_address);
  config[contract_name+"_PROXY_ADMIN_CONTRACT_ADDRESS"] = await hre.upgrades.erc1967.getAdminAddress(contract_address);
}

async function deployFanTigerContract(config) {
  const contractFactory= await hre.ethers.getContractFactory("V2FanTV_dapp");
  const nft_contract = await hre.upgrades.deployProxy(contractFactory, {kind:"transparent"});


  console.log(nft_contract.address);
  await nft_contract.deployed();
  await setProxyAddresses(config,"FANTIGER",nft_contract.address);
  return nft_contract;
}

async function main() {

  [owner] = await ethers.getSigners();
  config = {
    "OWNER_ADDRESS" : owner.address
  }

  tx = await deployFanTigerContract(config);
  console.log('NFT Contract',tx);
  console.log(config);
  fs.writeFileSync('./scripts/xfantv.json',JSON.stringify(config,null,4),{encoding: 'utf8',flag: 'w'});
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
  