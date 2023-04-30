const UniswapBot = artifacts.require('UniswapBot');

module.exports = function (deployer) {
	deployer.deploy(UniswapBot /* constructor arguments */);
};
