import Foundation

/// Monotonni cas v sekundach, ktery bezi i ve spanku zarizeni.
/// `ProcessInfo.systemUptime` se ve spanku zastavi, takze bitva se zamcenym telefonem
/// by trvala dele, nez ukazuji hodiny, a kontrola hodin by ji po probuzeni oznacila za podvod.
enum MonotonicClock {
    static var now: TimeInterval { Double(clock_gettime_nsec_np(CLOCK_MONOTONIC)) / 1_000_000_000 }
}
