module rest.api.sensor;

import vibe.http.server;
import vibe.web.auth : requiresAuth, anyAuth, auth, Role;
import vibe.web.rest;

import rest.auth.common;

@requiresAuth!AuthInfo
interface SensorAPI
{
@safe:
    @anyAuth @method(HTTPMethod.GET) @path("/latest")
    SensorList getLatest();

    mixin authInterfaceMethod;
}

struct SensorList
{
    string hostName;
    string timestamp;
    SensorDTO[] sensors;
}

struct SensorDTO
{
    string unit;
    string id;
    string label;
    double value;
}
