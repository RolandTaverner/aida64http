module rest.auth.errors;

import std.exception : basicExceptionCtors;

class AuthError : Exception
{
    mixin basicExceptionCtors;
}
