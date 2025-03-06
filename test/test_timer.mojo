from src import *
from testing import *

fn test_f65536() raises:
    var timer = Timer(Frequency.F65536)
    timer.on = True

    assert_equal(timer.step(123), False)
    assert_equal(timer.cycles, 59)
    assert_equal(timer.value, 1)
    assert_equal(timer.modulo, 0)

    for _ in range(254):
        assert_equal(timer.step(123), False)

    assert_equal(timer.step(123), True)
    assert_equal(timer.cycles, 0)
    assert_equal(timer.value, 0)
    assert_equal(timer.modulo, 0)

    assert_equal(timer.step(123), False)
    assert_equal(timer.cycles, 59)
    assert_equal(timer.value, 1)
    assert_equal(timer.modulo, 0)