module provider.sensors;

import core.sync.rwmutex : ReadWriteMutex;
import std.concurrency : ownerTid, receiveTimeout, send;
import std.conv : ConvException, to;
import std.datetime : seconds;
import std.datetime.systime : Clock, SysTime;
import std.datetime.timezone : UTC;

//import std.stdio : writeln;

import prometheus.gauge : Gauge;

import aida64.sensorvalues;
import aida64.parse;

public shared class SensorsProvider
{
    public this(string hostName)
    {
        this.hostName = hostName.idup;
        mutex = new shared ReadWriteMutex();
    }

    public void start()
    {
        while (!receiveTimeout(1.seconds, (int) { /*writeln("Worker: recieved stop message");*/ ownerTid.send("done");}))
        {
            char[] buf;
            try
            {
                buf = getSensorValuesData();
            }
            catch (Exception e)
            {
                // TODO: log
                continue;
            }

            auto sensors = parseRawData(buf);
            auto newData = new SensorDataStore(hostName, sensors);
            synchronized (mutex.writer)
            {
                // writeln("Worker: data updated");
                // TODO: log
                latestData = newData;
            }

            synchronized (mutex.reader)
            {
                auto sensorsData = getSensors();
                foreach(s; sensorsData.sensors)
                {
                    double value;
                    try 
                    {
                        value = to!double(s.value);
                    } 
                    catch (ConvException e) {
                        //writeln("Conversion failed: The string is not a valid number.");
                        // TODO: log
                        continue;
                    }
                    sensorGauge.set(value, [sensorsData.hostName, s.id, s.unit, s.label]);
                }
            }
        }

        // writeln("Worker: exit");
    }

    public immutable(SensorData) getSensors() @safe
    {
        synchronized (mutex.reader)
        {
            return SensorData(latestData.hostName, latestData.sensors.idup, latestData.timestamp);
        }
    }

    private SensorDataStore latestData;
    private ReadWriteMutex mutex;
    private string hostName;
    private Gauge gauge;
}

public struct SensorData
{
    immutable string hostName;
    immutable Sensor[] sensors;
    immutable SysTime timestamp;
}

private shared class SensorDataStore
{
    this(string hostName, Sensor[] sensors)
    {
        this.hostName = hostName;
        this.sensors = sensors.idup;
        this.timestamp = Clock.currTime(UTC());
    }

    immutable string hostName;
    immutable Sensor[] sensors;
    immutable SysTime timestamp;
}

private __gshared Gauge sensorGauge = new Gauge("aida64_sensor_value", "Values of AIDA64 sensors", ["host_name", "id", "unit", "label"]);

static this()
{
    sensorGauge.register();
}
