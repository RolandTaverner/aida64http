module rest.api.root;

import vibe.web.rest;
import vibe.http.server;

import rest.api.sensor : SensorAPI;

@path("/api/")
interface APIRoot
{
    @path("sensor/")
    @property SensorAPI sensor();
}
