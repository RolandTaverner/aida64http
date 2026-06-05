module aida64.sensorvalues;

import std.exception : enforce;
import std.format : format;

import windows.core;
import windows.win32.foundation : FALSE, PWSTR, TRUE, GetLastError;
import windows.win32.system.memory : MapViewOfFile, OpenFileMappingW, UnmapViewOfFile,
                                     MEMORY_MAPPED_VIEW_ADDRESS, FILE_MAP_READ;

import aida64.errors;

immutable wstring aidaFileMapping = "AIDA64_SensorValues";

public char[] getSensorValuesData()
{
	auto handle = OpenFileMappingW(FILE_MAP_READ, FALSE, PWSTR(cast(wchar*)aidaFileMapping.ptr)).autoFree;
	enforce(handle.Value != null, new WindowsError(GetLastError(), "OpenFileMappingW failed"));

	auto mappingAddress = MMViewAddress(MapViewOfFile(handle, FILE_MAP_READ, 0, 0, 0));
	enforce(!mappingAddress.isNull(), new WindowsError(GetLastError(), "MapViewOfFile returned NULL"));

    return copySensorValuesData(mappingAddress.address());
}

// copySensorValuesData returns copied data including last \0 symbol
private char[] copySensorValuesData(const void* addr)
{
	// https://www.aida64.com/user-manual/hardware-monitoring/external-applications?language_content_entity=en
	// The shared memory content is a long string value ending in a 0x00 char, making it a classic PChar or char*.
	// The buffer size (the size of the shared memory block) has to be at least 10 KB. A typical buffer size is
	// around 1 to 3 KB, but for Abit MicroGuru 2005 based boards, for example, it can be a lot more.
	immutable int maxSize = 65_536;
	auto buf = cast(char*)addr;
	int i = 0;
	for(i = 0; i < maxSize && buf[i] != 0; ++i) {}
	enforce(i != 0, new EmptySensorDataError("empty sensor data"));
	enforce(i < maxSize - 1, new TooLargeSensorDataError(format("sensor data too large")));
	return buf[0 .. i + 1].dup;
}

private struct MMViewAddress
{
    @disable this();
    @disable this(this);

    this(MEMORY_MAPPED_VIEW_ADDRESS address)
    {
        _address = MEMORY_MAPPED_VIEW_ADDRESS(address.Value);
    }

    ~this()
    {
        if (!isNull())
        {
            auto result = UnmapViewOfFile(_address);
            _address = MEMORY_MAPPED_VIEW_ADDRESS(null);
            assert(result == TRUE, "UnmapViewOfFile returned FALSE");
        }
    }

    const(void*) address() const
    {
        return _address.Value;
    }

    bool isNull() const
    {
        return _address.Value == null;
    }

    private MEMORY_MAPPED_VIEW_ADDRESS _address;
}
