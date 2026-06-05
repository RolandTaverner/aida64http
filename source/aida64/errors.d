module aida64.errors;

import std.exception : basicExceptionCtors;

import windows.win32.foundation : WIN32_ERROR;

public abstract class Aida64Error : Exception
{
    mixin basicExceptionCtors;
}

public class WindowsError : Aida64Error
{
    this(WIN32_ERROR lastErr, string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null) @nogc @safe pure nothrow
    {
        super(msg, file, line, next);
        _lastError = lastErr;
    }

    this(WIN32_ERROR lastErr, string msg, Throwable next, string file = __FILE__, size_t line = __LINE__) @nogc @safe pure nothrow
    {
        super(msg, file, line, next);
        _lastError = lastErr;
    }

    WIN32_ERROR lastError() @safe const pure
    {
        return _lastError;
    }

    private WIN32_ERROR _lastError;
}

public class EmptySensorDataError : Aida64Error
{
    mixin basicExceptionCtors;
}

public class TooLargeSensorDataError : Aida64Error
{
    mixin basicExceptionCtors;
}
