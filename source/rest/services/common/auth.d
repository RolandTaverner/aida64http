module rest.services.common.auth;

public import vibe.http.server : HTTPServerRequest, HTTPServerResponse;
public import vibe.web.auth : requiresAuth, anyAuth;
public import vibe.http.common : HTTPStatusException;
public import vibe.http.status : HTTPStatus;
public import vibe.web.common : noRoute;

public import rest.auth.provider : AuthInfo, AuthProvider;

mixin template authMethodImpl()
{
    @noRoute @safe override AuthInfo authenticate(scope HTTPServerRequest req, scope HTTPServerResponse res)
    {
        return authProvider().authenticate(req.headers.getAll("Authorization"));
    }

    private AuthProvider authProvider() @safe
    {
        return m_authProvider;
    }

    private AuthProvider m_authProvider;
}
