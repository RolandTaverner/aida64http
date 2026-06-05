module options;

import args : Arg, Optional, parseArgsConfigFile, parseConfigFile;

static struct Options
{
	@Arg("The interfaces on which the HTTP server is listening", Optional.yes) string[] bindAddresses;
	@Arg("The port on which the HTTP server is listening", Optional.yes) ushort port;
	@Arg("Path to log dir", Optional.yes) string logDir;
	@Arg("Path to server certificate chain file", Optional.yes) string certificateChainFile;
	@Arg("Path to private key file", Optional.yes) string privateKeyFile;
	@Arg("Path to trusted certificates for verifying peer certificates", Optional.yes) string trustedCertificateFile;
	@Arg("Auth tokens", Optional.yes) string[] authTokens;
}

Options getOptions(in string filePath)
{
	Options options;
    if (filePath.length == 0)
    {
        options.port = 8080;
        options.bindAddresses = ["127.0.0.1"];
        return options;
    }

	auto data = parseArgsConfigFile(filePath);
	parseConfigFile(options, data);

	return options;
}
