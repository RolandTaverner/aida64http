module provider.sensors;

import std.concurrency : ownerTid, receiveTimeout, send;
import core.sync.rwmutex : ReadWriteMutex;
import std.datetime : seconds;
import std.datetime.systime : Clock, SysTime;
import std.datetime.timezone : UTC;
//import std.stdio : writeln;

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
                latestData = newData;
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
}

public struct SensorData
{
    immutable string hostName;
    immutable Sensor[] sensors;
    immutable SysTime timestamp;
}

public void worker(void delegate() shared dg)
{
    dg();
    // writeln("Worker dg: exit");
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
