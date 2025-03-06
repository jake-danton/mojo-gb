from sys import stdout
from utils import StaticString

@value
@register_passable("trivial")
struct LogLevel(EqualityComparable, Stringable):
    var value: UInt8

    alias Debug = LogLevel(0)
    alias Info = LogLevel(1)
    alias Warning = LogLevel(2)
    alias Error = LogLevel(3)

    fn __eq__(self, other: LogLevel) -> Bool:
        return self.value == other.value

    fn __ne__(self, other: LogLevel) -> Bool:
        return self.value != other.value

    fn __lt__(self, other: LogLevel) -> Bool:
        return self.value < other.value

    fn __le__(self, other: LogLevel) -> Bool:
        return self.value <= other.value

    fn __gt__(self, other: LogLevel) -> Bool:
        return self.value > other.value

    fn __ge__(self, other: LogLevel) -> Bool:
        return self.value >= other.value

    fn __str__(self) -> String:
        if self == LogLevel.Debug:
            return "Debug"
        elif self == LogLevel.Info:
            return "Info"
        elif self == LogLevel.Warning:
            return "Warning"
        elif self == LogLevel.Error:
            return "Error"
        else:
            return String("Unknown LogLevel", self.value)

alias LOG_LEVEL = LogLevel.Info

fn log[level: LogLevel, *T: Stringable](*message: *T):
    @parameter
    if level >= LOG_LEVEL:
        var strings = List[String]()

        @parameter
        fn add[Type: Stringable](value: Type):
            strings.append(String(value))

        message.each[add]()

        print(" ".join(strings))