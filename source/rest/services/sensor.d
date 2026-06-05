module rest.services.sensor;

import std.algorithm.iteration : map;
import std.algorithm.mutation : SwapStrategy;
import std.algorithm.sorting : sort;
import std.array : array, replace;
import std.conv : to;

import vibe.web.auth;
import vibe.web.common : noRoute;

import provider.sensors;
import rest.api.sensor;
import rest.services.common.auth;

class SensorService : SensorAPI
{
    this(SensorsProvider model, AuthProvider authProvider)
    {
        m_model = model;
        m_authProvider = authProvider;
    }

    override SensorList getLatest() @safe
    {
        auto data = m_model.getSensors();
        SensorList result;
        result.hostName  = data.hostName.dup;
        result.timestamp = data.timestamp.toISOExtString().replace(":", "-").replace(".", "_");
        result.sensors = data.sensors.dup
            .map!(s => SensorDTO(s.unit, s.id, s.label, to!double(s.value))).array
            .sort!((a, b) => a.id < b.id, SwapStrategy.stable).array;

        return result;
    }

    mixin authMethodImpl;

private:
    SensorsProvider m_model;
}
