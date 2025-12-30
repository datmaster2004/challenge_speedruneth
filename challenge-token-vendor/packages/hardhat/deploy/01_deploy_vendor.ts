import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { Contract } from "ethers";

const deployVendor: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;

  // Get YourToken
  const yourToken = await hre.ethers.getContract<Contract>("YourToken", deployer);
  const yourTokenAddress = await yourToken.getAddress();

  // Deploy Vendor
  await deploy("Vendor", {
    from: deployer,
    args: [yourTokenAddress],
    log: true,
    autoMine: true,
  });

  const vendor = await hre.ethers.getContract<Contract>("Vendor", deployer);
  const vendorAddress = await vendor.getAddress();

  // Transfer tokens to Vendor
  await yourToken.transfer(vendorAddress, hre.ethers.parseEther("1000"));

  // Transfer ownership to frontend address
  await vendor.transferOwnership("0x931F04BeC199104D0A783032CE35d7dA513246e8");
};

export default deployVendor;
deployVendor.tags = ["Vendor"];
