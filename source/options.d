module options;

import std.conv : to;

import args : Arg, Optional, parseArgsConfigFile, parseConfigFile;

import windows.win32.system.windowsprogramming : GetComputerNameW, MAX_COMPUTERNAME_LENGTH;
import windows.win32.foundation : PWSTR, TRUE;

static struct Options
{
	@Arg("The interfaces on which the HTTP server is listening", Optional.yes) string[] bindAddresses;
	@Arg("The port on which the HTTP server is listening", Optional.yes) ushort port;
	@Arg("Host name for metrics", Optional.yes) string hostName;
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
		options.hostName = getHostName();
        return options;
    }

	auto data = parseArgsConfigFile(filePath);
	parseConfigFile(options, data);

	if (options.hostName.length == 0)
	{
		options.hostName = getHostName();
	}

	return options;
}

private string getHostName()
{
	wchar[] buf = new wchar[MAX_COMPUTERNAME_LENGTH + 1];
	uint size = MAX_COMPUTERNAME_LENGTH;
	if (GetComputerNameW(PWSTR(buf.ptr), &size) != TRUE)
	{
		return "";
	}

	wstring name = buf[0 .. size].idup;
	return name.to!string;
}