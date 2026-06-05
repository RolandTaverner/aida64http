module aida64http;

import std.conv : to;
import std.exception : enforce;
import std.format : format;

import windows.win32.ui.windowsandmessaging : MessageBoxW, MB_OK, MB_ICONERROR;
import windows.win32.foundation : HWND, PWSTR;

import aida64.sensorvalues;

int main(string[] args)
{
	wstring errCaption = "Error";

	char[] buf;
	try 
	{
		buf = getSensorValuesData();
	}
	catch(Exception e)
	{
		auto errText = to!wstring(e.message);
		errText ~= 0;
		MessageBoxW(HWND(null), PWSTR(cast(wchar*)errText.ptr), PWSTR(cast(wchar*)errCaption.ptr), MB_OK | MB_ICONERROR);
		return 1;
	}

	string s = buf.idup;

	wstring c = "Data";
	wstring msg = s.to!wstring;

	MessageBoxW(HWND(null), PWSTR(cast(wchar*)msg.ptr), PWSTR(cast(wchar*)c.ptr), 0);
	return 0;
}
