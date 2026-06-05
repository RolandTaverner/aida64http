module rest.auth.provider;

import std.algorithm.searching : startsWith;
import std.string : chompPrefix;

import vibe.http.common : HTTPStatusException;
import vibe.http.status : HTTPStatus;

import rest.auth.errors;

public struct AuthInfo
{
@safe:
    bool reader;
    string token;

    bool isReader() 
    {
        return reader;
    }
}

enum MaxUserSessions = 100;

public class AuthProvider
{
    this(in string[] tokens, bool noAuth)
    {
        m_noAuth = noAuth;
        foreach(t; tokens)
        {
            m_validTokens[t] = true;
        }
    }

    AuthInfo authenticate(in string[] authValues) @safe
    {
        if (m_noAuth)
        {
            return AuthInfo(true, "any");
        }

        auto token = getValidPayload(authValues);
        if (token.length == 0)
        {
            throw new HTTPStatusException(HTTPStatus.forbidden, "missing token");
        }

        if (token !in m_validTokens)
        {
            throw new HTTPStatusException(HTTPStatus.forbidden, "invalid token");
        }

        AuthInfo ai = {
            reader: true,
            token: token,
        };

        return ai;
    }

private:

    string getValidPayload(in string[] authValues) @safe
    {
        const auto bearer = "Bearer ";
        foreach (authValue; authValues)
        {
            if (!authValue.startsWith(bearer))
            {
                continue;
            }
            return authValue.chompPrefix(bearer);
        }

        if (!m_noAuth)
        {
            throw new HTTPStatusException(HTTPStatus.forbidden, "no valid authorization header found");
        }

        return "";
    }

    bool m_noAuth;
    bool[string] m_validTokens;
}
