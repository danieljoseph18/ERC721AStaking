const PatrickiezStaking = artifacts.require("PatrickiezStaking");

module.exports = async function(deployer){
    await deployer.deploy(PatrickiezStaking);
}