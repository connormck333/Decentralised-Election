var Election = artifacts.require("Election");

module.exports = function(deployer) {
  deployer.deploy(Election, ["Antrim", "Down", "Tyrone", "Fermanagh", "LondonDerry", "Armagh"]);
};