# HTTP API for AIDA64

aida64http is a small application providing integration with [AIDA64](https://www.aida64.com/) via [shared memory](https://www.aida64.com/user-manual/hardware-monitoring/external-applications?language_content_entity=en).

The goal of this application is to provide an easy way to integrate custom scripts with [AIDA64](https://www.aida64.com/). aida64http also provides a Prometheus endpoint, so if you have a spare server running Prometheus and Grafana, you can create a Grafana dashboard.

Low memory footprint: 3-6 MB, ~0 CPU load.

# API

## Latest values for sensors
aida64http updates sensor values every second in the background.

Request: `curl 127.0.0.1:8080/api/sensor/latest`

Response:

```json
{
    "hostName": "MyPC",
    "timestamp": "2026-06-05T21-11-20_1123147Z",
    "sensors": [
        {
            "unit": "curr",
            "id": "CGPU1PCIE",
            "label": "GPU PCIe",
            "value": 0.45
        },
        {
            "unit": "duty",
            "id": "DGPU1",
            "label": "GPU",
            "value": 28
        },
        {
            "unit": "fan",
            "id": "FCHA3",
            "label": "Chassis #3",
            "value": 1520
        },
        {
            "unit": "fan",
            "id": "FCPU",
            "label": "CPU",
            "value": 1360
        },
        {
            "unit": "pwr",
            "id": "PCPUIAC",
            "label": "CPU IA Cores",
            "value": 54.06
        },
        {
            "unit": "sys",
            "id": "SCPUCLK",
            "label": "CPU Clock",
            "value": 3689
        },
        {
            "unit": "sys",
            "id": "SCPUUTI",
            "label": "CPU Utilization",
            "value": 6
        },
        {
            "unit": "temp",
            "id": "TCC-1-1",
            "label": "CPU Core #1",
            "value": 49
        }
    ]
}
```

## Prometheus metrics endpoint

Request: `curl 127.0.0.1:8080/metrics`

# How to build

Install [the DMD compiler with DUB](https://dlang.org/dmd-windows.html#installation) or alternatively LDC or GDC.

Create a directory, for example C:\work

```
cd C:\work
git clone https://github.com/RolandTaverner/windows-d.git
git clone https://github.com/RolandTaverner/aida64http.git
cd aida64http
dub build -b release
```
The executable will be created at `bin\release\aida64http.exe`

# How to run

Run `aida64http.exe`.

# Configuration

Optionally, a configuration file can be provided:

```
aida64http.exe --config path\to\file\aida64http.conf
```

## Configuration file format

All configuration options are optional, as is the configuration file itself.

```
# default = 127.0.0.1
bindAddresses = 0.0.0.0 

# default = 8080
port = 10064

# default = Windows PC name returned by GetComputerNameW(), see https://learn.microsoft.com/ru-ru/windows/win32/api/winbase/nf-winbase-getcomputernamew
hostName = "My PC"

# Directory for log files. Logging is disabled if not set.
logDir = "c:\some\log"

# HTTPS settings. HTTPS is disabled if not configured.
certificateChainFile = "ca.crt"
privateKeyFile = "host.key"
trustedCertificateFile = "host.crt"

# Authorization tokens. If configured, one of them must be provided in the HTTP header: 'Authorization: Bearer aaa'.
authTokens = aaa,bbb
```

# Tech details

Implemented in [D language](https://dlang.org) with [vibe.d](https://vibed.org) as HTTP server, [andrewbenton/prometheus-d](https://github.com/andrewbenton/prometheus-d) as Prometheus metrics provider, [RolandTaverner/windows-d](https://github.com/RolandTaverner/windows-d) as Windows API projection for D.
