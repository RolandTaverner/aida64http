module rest.service;

import vibe.vibe;
import vibe.http.common;

import provider.sensors;
import rest.api.root;
import rest.api.sensor;
import rest.auth.provider : AuthProvider;
import rest.services.sensor;

class Service : APIRoot
{
    this(SensorsProvider model, AuthProvider authProvider)
    {
        m_model = model;
        m_sensorSvc = new SensorService(model, authProvider);
    }

    override @property SensorAPI sensor()
    {
        return m_sensorSvc;
    }

private:
    SensorsProvider m_model;
    SensorService m_sensorSvc;
}
