module aida64.parse;

import std.format : format;
import std.typecons : nullable, Nullable, tuple, Tuple;

public struct Sensor
{
    string unit;
    string id;
    string label;
    string value;
}

public Sensor[] parseRawData(in const(char)[] data)
{
    Sensor[] result;
    const(char)[] d = data;
    
    bool finished = false;
    while (!finished)
    {
        auto sensor = consumeSensor(d);
        if (!sensor.isNull)
        {
            result ~= sensor.get;
        }
        else
        {
            finished = true;
        }
    }

    return result;
}

unittest
{
    const(char)[] data = "<temp><id>TMOBO</id><label>Motherboard</label><value>33</value></temp><pwr><id>PGPU1TDPP</id><label>GPU TDP%</label><value>28</value></pwr><fan><id>FGPU1GPU2</id><label>GPU2</label><value>0</value></fan>".dup;
    auto sensors = parseRawData(data);
    assert(sensors.length == 3);

    assert(sensors[0].unit == "temp");
    assert(sensors[0].id == "TMOBO");
    assert(sensors[0].label == "Motherboard");
    assert(sensors[0].value == "33");

    assert(sensors[1].unit == "pwr");
    assert(sensors[1].id == "PGPU1TDPP");
    assert(sensors[1].label == "GPU TDP%");
    assert(sensors[1].value == "28");

    assert(sensors[2].unit == "fan");
    assert(sensors[2].id == "FGPU1GPU2");
    assert(sensors[2].label == "GPU2");
    assert(sensors[2].value == "0");
}

private Nullable!Sensor consumeSensor(ref const(char)[] data)
{
    auto sensorOpenTag = openTag(data);
    if (sensorOpenTag.length == 0)
    {
        return (Nullable!Sensor).init;
    }
    data = data[sensorOpenTag.consumed .. $];

    TagValue[] tagValues;
    for(int i = 1; i <= 3; ++i)
    {
        auto tv = consumeTagValue(data);
        if (tv.consumed == 0)
        {
            break;
        }
        tagValues ~= tv;
        data = data[tv.consumed .. $];
    }
    if (tagValues.length != 3)
    {
        return (Nullable!Sensor).init;
    }

    auto sensorCloseTag = closeTag(data, true);
    if (sensorCloseTag.length == 0 || sensorCloseTag.tag != sensorOpenTag.tag)
    {
        return (Nullable!Sensor).init;
    }
    data = data[sensorCloseTag.consumed .. $];

    string id, label, value;
    foreach(tv; tagValues)
    {
        if (tv.tag == "id")
        {
            id = tv.value.idup;
        }
        else if (tv.tag == "label")
        {
            label = tv.value.idup;
        }
        else if (tv.tag == "value")
        {
            value = tv.value.idup;
        }
    }

    if (id.length == 0 || label.length == 0 || value.length == 0)
    {
        return (Nullable!Sensor).init;
    }

    return nullable(Sensor(sensorOpenTag.tag.idup, id, label, value));
}

unittest
{
    const(char)[] data = "<temp><id>THDD1</id><label>Samsung SSD 990 PRO 1TB</label><value>45</value></temp>".dup;
    Nullable!Sensor s = consumeSensor(data);
    assert(!s.isNull);
    assert(data.length == 0);
    assert(s.get.unit == "temp");
    assert(s.get.id == "THDD1");
    assert(s.get.label == "Samsung SSD 990 PRO 1TB");
    assert(s.get.value == "45");

    data = "temp><id>THDD1</id><label>Samsung SSD 990 PRO 1TB</label><value>45</value></temp>".dup;
    s = consumeSensor(data);
    assert(s.isNull);

    data = "<temp><id>THDD1</id><label></label><value>45</value></temp>".dup;
    s = consumeSensor(data);
    assert(s.isNull);

    data = "<temp><id>THDD1</id><label>Samsung SSD 990 PRO 1TB</label><value>45</value>".dup;
    s = consumeSensor(data);
    assert(s.isNull);
}

private alias TagValue = Tuple!(const(char)[], "tag", const(char)[], "value", int, "consumed");

private TagValue consumeTagValue(const char[] data)
{
    auto sensorOpenTag = openTag(data);
    if (sensorOpenTag.tag.length == 0)
    {
        return TagValue([], [], 0);
    }
    int consumed = sensorOpenTag.consumed;

    auto value = consumeUntilCloseTag(data[consumed .. $]);
    if (value.length == 0)
    {
        return TagValue([], [], 0); 
    }
    consumed += value.length;

    auto sensorCloseTag = closeTag(data[consumed .. $], false);
    if (sensorCloseTag.tag.length == 0 || sensorOpenTag.tag != sensorCloseTag.tag)
    {
        return TagValue([], [], 0);
    }
    consumed += sensorCloseTag.consumed;

    return TagValue(sensorOpenTag.tag, value, consumed);
}

unittest
{
    char[] data = "  <id> THDD1 </id>".dup;
    TagValue tv = consumeTagValue(data);
    assert(tv.consumed == data.length);
    assert(tv.tag == "id");
    assert(tv.value == " THDD1 ");
    
    data = "<id> THDD1 </id1>".dup;
    tv = consumeTagValue(data);
    assert(tv.consumed == 0);
    assert(tv.tag == "");
    assert(tv.value == "");

    data = "THDD1 </id1>".dup;
    tv = consumeTagValue(data);
    assert(tv.consumed == 0);
    assert(tv.tag == "");
    assert(tv.value == "");

    data = "<a></a>".dup;
    tv = consumeTagValue(data);
    assert(tv.consumed == 0);
    assert(tv.tag == "");
    assert(tv.value == "");

    data = "<a> </a>".dup;
    tv = consumeTagValue(data);
    assert(tv.consumed == data.length);
    assert(tv.tag == "a");
    assert(tv.value == " ");
}

private alias Tag = Tuple!(const(char)[], "tag", int, "consumed");

private Tag openTag(const char[] data)
{
    if (data.length == 0)
    {
        return Tag("", 0);
    }

    int consumed = consumeSpaces(data);
    if (consumed >= data.length || data[consumed] != '<')
    {
        return Tag("", 0);
    }
    ++consumed;
    
    auto tagName = consumeChars!(isAlpha)(data[consumed .. $]);
    if (tagName.length == 0)
    {
        return Tag("", 0);
    }
    consumed += tagName.length;
    if (consumed >= data.length || data[consumed] != '>')
    {
        return Tag("", 0);
    }
    ++consumed;

    return Tag(tagName, consumed);
}

unittest
{
    char[] data = [];
    Tag t = openTag(data);
    assert(t.tag == "");
    assert(t.consumed == 0);

    data = " ".dup;
    t = openTag(data);
    assert(t.tag == "");
    assert(t.consumed == 0);

    data = ">aa".dup;
    t = openTag(data);
    assert(t.tag == "");
    assert(t.consumed == 0);

    data = "<aa".dup;
    t = openTag(data);
    assert(t.tag == "");
    assert(t.consumed == 0);

    data = "<>".dup;
    t = openTag(data);
    assert(t.tag == "");
    assert(t.consumed == 0);

    data = "<aa>".dup;
    t = openTag(data);
    assert(t.tag == "aa");
    assert(t.consumed == 4);

    data = "  <aa>".dup;
    t = openTag(data);
    assert(t.tag == "aa");
    assert(t.consumed == 6);
}

private Tag closeTag(const char[] data, bool consumeWithSpaces)
{
    if (data.length == 0)
    {
        return Tag("", 0);
    }

    int consumed = consumeWithSpaces ? consumeSpaces(data) : 0;
    if (consumed + 3 >= data.length || (data[consumed] != '<' || data[consumed + 1] != '/'))
    {
        return Tag("", 0);
    }
    consumed += 2;
    
    auto tagName = consumeChars!(isAlpha)(data[consumed .. $]);
    if (tagName.length == 0)
    {
        return Tag("", 0);
    }
    consumed += tagName.length;
    if (consumed >= data.length || data[consumed] != '>')
    {
        return Tag("", 0);
    }
    ++consumed;

    return Tag(tagName, consumed);
}

unittest
{
    char[] data = [];
    Tag t = closeTag(data, false);
    assert(t.tag == "");
    assert(t.consumed == 0);

    data = "<aa".dup;
    t = closeTag(data, false);
    assert(t.tag == "");
    assert(t.consumed == 0);

    data = "</aa".dup;
    t = closeTag(data, false);
    assert(t.tag == "");
    assert(t.consumed == 0);

    data = "</>".dup;
    t = closeTag(data, false);
    assert(t.tag == "");
    assert(t.consumed == 0);

    data = "</aa>".dup;
    t = closeTag(data, false);
    assert(t.tag == "aa");
    assert(t.consumed == 5);

    data = "  </aa>".dup;
    t = closeTag(data, true);
    assert(t.tag == "aa");
    assert(t.consumed == 7);

    data = "</a>".dup;
    t = closeTag(data, false);
    assert(t.tag == "a");
    assert(t.consumed == 4);
}

private const(char)[] consumeUntilCloseTag(const char[] data)
{
    int i = 0;
    for(; i + 4 < data.length && closeTag(data[i .. $], false).tag.length == 0; ++i) {}
    return data[0 .. i];
}

private const(char)[] consumeChars(alias testChar)(const char[] data)
{
    int i = 0;
    for(; i < data.length && testChar(data[i]); ++i) {}
    if (i == 0 )
    {
        return "";
    }

    return data[0 .. i].idup;
}

unittest
{
    char[] data = [];
    assert(consumeChars!((char c) => c == 's')(data) == []);

    data = "abc".dup;
    assert(consumeChars!((char c) => c == 'a' || c == 'b')(data) == "ab");

    data = "abc".dup;
    assert(consumeChars!((char c) => c == 'c')(data) == "");
}

private int consumeSpaces(const char[] data)
{
    int spaces = 0;
    for(; spaces < data.length && (data[spaces] == ' ' || data[spaces] == '\t'); ++spaces) {}
    return spaces;
}

unittest
{
    char[] data = [];
    assert(consumeSpaces(data) == 0);

    data = "   s".dup;
    int spaces = consumeSpaces(data);
    assert(spaces == 3, format("got %d, expected 3", spaces));

    data = "   ".dup;
    spaces = consumeSpaces(data);
    assert(spaces == 3, format("got %d, expected 3", spaces));

    data = "<> ".dup;
    spaces = consumeSpaces(data);
    assert(spaces == 0, format("got %d, expected 0", spaces));
}

private bool isAlpha(const char c)
{
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
}
