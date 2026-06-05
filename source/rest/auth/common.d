module rest.auth.common;

public import vibe.http.server : HTTPServerRequest, HTTPServerResponse;
public import vibe.web.auth : requiresAuth, anyAuth;
public import vibe.web.common : noRoute;

public import rest.auth.provider : AuthInfo;

mixin template authInterfaceMethod()
{
    @noRoute AuthInfo authenticate(scope HTTPServerRequest req, scope HTTPServerResponse res);
}
