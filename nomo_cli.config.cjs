const nomoCliConfig = {
    deployTargets: {
        production: {
            rawSSH: {
                sshHost: process.env.SSH_TARGET,
                sshBaseDir: "/var/www/production_webons/swaptheme/",
                publicBaseUrl: "https://zeniqswap.nomo.zone",
                hybrid: true,
            },
        },
    },
};

module.exports = nomoCliConfig;