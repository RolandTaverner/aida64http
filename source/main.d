module aida64http;

import std.concurrency : receiveOnly, send, spawn, Tid;
import std.conv : to;
import std.exception : enforce;
import std.format : format;
import std.path : buildPath;
import std.stdio : writeln;

import vibe.core : finalizeCommandLineOptions, logInfo, printCommandLineHelp, readOption, runApplication;
import vibe.http.router: URLRouter;
import vibe.http.server : HTTPServerSettings, listenHTTP;
import vibe.stream.tls : createTLSContext, TLSContextKind;
import vibe.web.rest : registerRestInterface, RestInterfaceSettings;

import windows.win32.ui.windowsandmessaging : MessageBoxW, MB_OK, MB_ICONERROR;
import windows.win32.foundation : HWND, PWSTR;

import options;
import provider.sensors : SensorsProvider, worker;
import rest.auth.provider : AuthProvider;
import rest.service : Service;

int main(string[] args)
{
	string configPath = ""; // aida64http.conf
	readOption("config", &configPath, "Path to the configuration file.");

	Options opts;
	try
	{
		opts = getOptions(configPath);
	}
	catch (Exception e)
	{
		writeln("Invalid argumens: ", e.message());
		printCommandLineHelp();
		return -1;
	}
	finalizeCommandLineOptions();

	SensorsProvider provider = new SensorsProvider("this");
	auto workerThread = spawn(&worker, &provider.start);
	scope (exit)
	{
		writeln("Stopping Worker...");
		workerThread.send(0);
		string result = receiveOnly!string();
		writeln("Worker finished ", result);
	}

	AuthProvider authProvider = new AuthProvider(opts.authTokens, opts.authTokens.length == 0);
	Service restService = new Service(provider, authProvider);

	auto restSettings = new RestInterfaceSettings;
	auto router = new URLRouter;
	registerRestInterface(router, restService, restSettings);

	auto settings = new HTTPServerSettings;
	settings.bindAddresses = opts.bindAddresses.length != 0 ? opts.bindAddresses : ["127.0.0.1"];
	settings.port = opts.port != 0 ? opts.port : 8080;
	settings.useCompressionIfPossible = true;

	if (opts.privateKeyFile.length != 0)
	{
		settings.tlsContext = createTLSContext(TLSContextKind.server);
		settings.tlsContext.useCertificateChainFile(opts.certificateChainFile);
		settings.tlsContext.usePrivateKeyFile(opts.privateKeyFile);
	}

	if (opts.logDir.length != 0)
	{
		settings.accessLogFile = buildPath(opts.logDir, "access.log");
	}

	auto listener = listenHTTP(settings, router);
	scope (exit)
	{
		listener.stopListening();
	}

	logInfo("Listening " ~ (opts.privateKeyFile.length != 0 ? "https" : "http") ~ "://127.0.0.1:" 
		~ to!(string)(opts.port));
	runApplication(&args);

	// wstring errCaption = "Error";

	// char[] buf;
	// try 
	// {
	// 	buf = getSensorValuesData();
	// }
	// catch(Exception e)
	// {
	// 	auto errText = to!wstring(e.message);
	// 	errText ~= 0;
	// 	MessageBoxW(HWND(null), PWSTR(cast(wchar*)errText.ptr), PWSTR(cast(wchar*)errCaption.ptr), MB_OK | MB_ICONERROR);
	// 	return 1;
	// }
	// auto sensors = parseRawData(buf);
	// foreach(s; sensors)
	// {
	// 	writeln(s);
	// }
	// string s = buf.idup;
	// writeln(s);

	// wstring c = "Data";
	// wstring msg = s.to!wstring;

	//MessageBoxW(HWND(null), PWSTR(cast(wchar*)msg.ptr), PWSTR(cast(wchar*)c.ptr), 0);
	return 0;
}
