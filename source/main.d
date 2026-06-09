module aida64http;

import core.runtime;
import std.concurrency : receiveOnly, send, spawn, Tid;
import std.conv : to;
import std.exception : enforce;
import std.format : format;
import std.path : buildPath;
import std.stdio : writeln;
import std.string : fromStringz;
import std.utf : toUTF16z;

import windows.win32.foundation : HINSTANCE, HLOCAL, HWND, PWSTR, LocalFree;
import windows.win32.system.environment : GetCommandLineW;
import windows.win32.ui.windowsandmessaging : MessageBoxW, MB_OK, MB_ICONERROR;
import windows.win32.ui.shell : CommandLineToArgvW;

import prometheus.registry : Registry;
import prometheus.vibe : handleMetrics;
import vibe.core : finalizeCommandLineOptions, logInfo, printCommandLineHelp, readOption, runApplication, setCommandLineArgs;
import vibe.http.router: URLRouter;
import vibe.http.server : HTTPServerSettings, listenHTTP;
import vibe.stream.tls : createTLSContext, TLSContextKind;
import vibe.web.rest : registerRestInterface, RestInterfaceSettings;

import options;
import window.msgloop : MessageLoop;
import provider.sensors : SensorsProvider;
import rest.auth.provider : AuthProvider;
import rest.service : Service;

extern(Windows)
int wWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, PWSTR lpCmdLine, int iCmdShow)
{
    int result;
    try
    {
        Runtime.initialize();

		auto cmdLine = GetCommandLineW();
        int numArgs;
		PWSTR* argsList = CommandLineToArgvW(cmdLine, &numArgs);

		string[] args;
		for(int i = 0; i < numArgs; ++i)
		{
			wstring arg = argsList[i].Value.fromStringz.idup;
			args ~= to!string(arg);
		}
		auto lfRes = LocalFree(HLOCAL(cast(void*)argsList));
		assert(lfRes.Value == null);

		result = myWinMain(hInstance, hPrevInstance, args, iCmdShow);
        Runtime.terminate();
    }
    catch(Throwable o)
    {
        MessageBoxW(HWND(null), PWSTR(cast(wchar*)o.toString().toUTF16z), PWSTR(cast(wchar*)"Error".toUTF16z), MB_OK | MB_ICONERROR);
        result = 0;
    }

    return result;
}

int myWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, string[] args, int iCmdShow)
{
	setCommandLineArgs(args);

	string configPath = ""; // aida64http.conf
	readOption("config", &configPath, "Path to the configuration file.");

	Options opts;
	try
	{
		opts = getOptions(configPath);
	}
	catch (Exception e)
	{
		// TODO: show message
		writeln("Invalid argumens: ", e.message());
		printCommandLineHelp();
		return -1;
	}
	finalizeCommandLineOptions();

	MessageLoop msgLoop = new MessageLoop(hInstance);
	auto msgLoopWorkerThread = spawn(&worker, &msgLoop.run);
	scope (exit)
	{
		//writeln("Stopping Windows message loop...");
//		msgLoop.stop();
		// string result = receiveOnly!string();
		//writeln("Worker finished ", result);
	}

	SensorsProvider provider = new SensorsProvider(opts.hostName);
	auto providerWorkerThread = spawn(&worker, &provider.start);
	scope (exit)
	{
		writeln("Stopping Worker...");
		providerWorkerThread.send(0);
		string result = receiveOnly!string();
		writeln("Worker finished ", result);
	}

	AuthProvider authProvider = new AuthProvider(opts.authTokens, opts.authTokens.length == 0);
	Service restService = new Service(provider, authProvider);

	auto restSettings = new RestInterfaceSettings;
	auto router = new URLRouter;
	registerRestInterface(router, restService, restSettings);
	router.get("/metrics", handleMetrics(Registry.global));

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

	runApplication(&args);

	return 0;
}

int main(string[] args)
{
	return 0;
}

private void worker(void delegate() shared dg)
{
    dg();
}
