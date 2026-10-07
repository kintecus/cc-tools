#!/usr/bin/env swift
//
// calendar-ek — EventKit-backed calendar writer for the /calendar skill.
//
// Exists because Calendar.app's AppleScript interface cannot manage alarms:
// `delete every display alarm of <event>` fails with "AppleEvent handler
// failed. (-10000)", and events created via `make new event` silently inherit
// the account's default alert. That makes "no alerts" unachievable over
// AppleScript. EventKit sets `alarms = nil` cleanly, so writes go through here.
//
// Usage:
//   calendar-ek calendars
//   calendar-ek list    --calendar NAME --from YYYY-MM-DD --to YYYY-MM-DD [--title TEXT]
//   calendar-ek create  --calendar NAME --title TEXT
//                       ( --start "YYYY-MM-DD HH:MM" (--end "YYYY-MM-DD HH:MM" | --duration MIN)
//                       | --dates YYYY-MM-DD,YYYY-MM-DD,... --time HH:MM --duration MIN )
//                       [--notes TEXT] [--location TEXT] [--rrule RRULE]
//                       [--alarm-minutes N ...] [--all-day]
//   calendar-ek delete  --calendar NAME (--id ID ... | --title TEXT --from DATE --to DATE)
//                       (recurring: whole series; single occurrences are `skip`)
//   calendar-ek skip    --calendar NAME (--id ID ... | --title TEXT ...)
//                       (--dates YYYY-MM-DD,... | --from DATE --to DATE) [--dry-run]
//   calendar-ek strip-alarms --calendar NAME --from DATE --to DATE [--title TEXT]
//
// Events are created with NO alarms unless --alarm-minutes is passed.
// Times are local. --dates creates independent one-off events, which is the
// right shape for an irregular ("loosely recurring") schedule; --rrule creates
// a single real recurring series.
//

import EventKit
import Foundation

// MARK: - Arguments

struct Args {
    var positional: [String] = []
    var flags: [String: [String]] = [:]

    init(_ argv: [String]) {
        var i = 0
        while i < argv.count {
            let a = argv[i]
            if a == "--" { i += 1; continue }
            if a.hasPrefix("--") {
                let key = String(a.dropFirst(2))
                if i + 1 < argv.count && !argv[i + 1].hasPrefix("--") {
                    flags[key, default: []].append(argv[i + 1])
                    i += 2
                } else {
                    flags[key, default: []].append("true")
                    i += 1
                }
            } else {
                positional.append(a)
                i += 1
            }
        }
    }

    func one(_ k: String) -> String? { flags[k]?.last }
    func all(_ k: String) -> [String] { flags[k] ?? [] }
    func has(_ k: String) -> Bool { flags[k] != nil }
    func require(_ k: String) -> String {
        guard let v = one(k) else { die("missing required --\(k)") }
        return v
    }
}

func die(_ msg: String) -> Never {
    FileHandle.standardError.write(Data(("error: " + msg + "\n").utf8))
    exit(1)
}

// MARK: - Store access

func grantedStore() -> EKEventStore {
    let store = EKEventStore()
    let sem = DispatchSemaphore(value: 0)
    var ok = false
    if #available(macOS 14.0, *) {
        store.requestFullAccessToEvents { granted, _ in ok = granted; sem.signal() }
    } else {
        store.requestAccess(to: .event) { granted, _ in ok = granted; sem.signal() }
    }
    sem.wait()
    guard ok else {
        die("Calendar access denied. System Settings > Privacy & Security > Calendars, enable your terminal.")
    }
    return store
}

/// Titles are not unique — subscribed holiday calendars in particular arrive
/// once per account — so `--source` is the tiebreaker.
func calendar(named name: String, source: String?, in store: EKEventStore) -> EKCalendar {
    var matches = store.calendars(for: .event).filter { $0.title == name }
    if matches.isEmpty {
        let known = store.calendars(for: .event)
            .map { "\($0.title)\t[\($0.source.title)]" }
            .sorted().joined(separator: "\n  ")
        die("no calendar titled \"\(name)\". Available:\n  \(known)")
    }
    if let source { matches = matches.filter { $0.source.title == source } }
    if matches.isEmpty {
        die("no calendar titled \"\(name)\" in source \"\(source ?? "")\"")
    }
    if matches.count > 1 {
        let srcs = matches.map { $0.source.title }.joined(separator: ", ")
        die("\(matches.count) calendars titled \"\(name)\" (sources: \(srcs)). Pass --source to pick one.")
    }
    return matches[0]
}

// MARK: - Dates

let localFmt: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = .current
    f.dateFormat = "yyyy-MM-dd HH:mm"
    return f
}()

let dayFmt: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = .current
    f.dateFormat = "yyyy-MM-dd"
    return f
}()

let stampFmt: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = .current
    f.dateFormat = "yyyy-MM-dd (EEE) HH:mm"
    return f
}()

/// Accepts "YYYY-MM-DD" (midnight) or "YYYY-MM-DD HH:MM".
func parseLocal(_ s: String, what: String) -> Date {
    if let d = localFmt.date(from: s) { return d }
    if let d = dayFmt.date(from: s) { return d }
    die("cannot parse \(what) \"\(s)\" — use YYYY-MM-DD or \"YYYY-MM-DD HH:MM\"")
}

// MARK: - RRULE

func parseRRule(_ raw: String) -> EKRecurrenceRule {
    var parts: [String: String] = [:]
    let body = raw.uppercased().replacingOccurrences(of: "RRULE:", with: "")
    for kv in body.split(separator: ";") {
        let bits = kv.split(separator: "=", maxSplits: 1)
        if bits.count == 2 { parts[String(bits[0])] = String(bits[1]) }
    }

    guard let freqRaw = parts["FREQ"] else { die("RRULE must contain FREQ") }
    let freq: EKRecurrenceFrequency
    switch freqRaw {
    case "DAILY": freq = .daily
    case "WEEKLY": freq = .weekly
    case "MONTHLY": freq = .monthly
    case "YEARLY": freq = .yearly
    default: die("unsupported FREQ=\(freqRaw)")
    }

    let interval = max(1, Int(parts["INTERVAL"] ?? "1") ?? 1)

    var daysOfWeek: [EKRecurrenceDayOfWeek]?
    if let byday = parts["BYDAY"] {
        let codes: [String: EKWeekday] = [
            "SU": .sunday, "MO": .monday, "TU": .tuesday, "WE": .wednesday,
            "TH": .thursday, "FR": .friday, "SA": .saturday,
        ]
        daysOfWeek = byday.split(separator: ",").map { token in
            let t = String(token)
            guard t.count >= 2, let wd = codes[String(t.suffix(2))] else {
                die("bad BYDAY token \"\(t)\"")
            }
            return EKRecurrenceDayOfWeek(wd, weekNumber: Int(t.dropLast(2)) ?? 0)
        }
    }

    let numbers: (String) -> [NSNumber]? = { key in
        parts[key]?.split(separator: ",").compactMap { Int($0) }.map { NSNumber(value: $0) }
    }

    var end: EKRecurrenceEnd?
    if let count = parts["COUNT"], let n = Int(count) {
        end = EKRecurrenceEnd(occurrenceCount: n)
    } else if let until = parts["UNTIL"] {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        if until.hasSuffix("Z") {
            f.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
            f.timeZone = TimeZone(identifier: "UTC")
        } else if until.count == 8 {
            f.dateFormat = "yyyyMMdd"
            f.timeZone = .current
        } else {
            f.dateFormat = "yyyyMMdd'T'HHmmss"
            f.timeZone = .current
        }
        guard let d = f.date(from: until) else { die("bad UNTIL=\(until)") }
        end = EKRecurrenceEnd(end: d)
    }

    return EKRecurrenceRule(
        recurrenceWith: freq,
        interval: interval,
        daysOfTheWeek: daysOfWeek,
        daysOfTheMonth: numbers("BYMONTHDAY"),
        monthsOfTheYear: numbers("BYMONTH"),
        weeksOfTheYear: nil,
        daysOfTheYear: nil,
        setPositions: numbers("BYSETPOS"),
        end: end)
}

// MARK: - Queries

/// EventKit enumerates one hit per occurrence; dedupe to one row per event object.
func uniqueEvents(
    in cal: EKCalendar, store: EKEventStore, from: Date, to: Date, title: String?
) -> [EKEvent] {
    let pred = store.predicateForEvents(withStart: from, end: to, calendars: [cal])
    var seen = Set<String>()
    var out: [EKEvent] = []
    for ev in store.events(matching: pred).sorted(by: { $0.startDate < $1.startDate }) {
        if let t = title, ev.title != t { continue }
        guard let id = ev.eventIdentifier, !seen.contains(id) else { continue }
        seen.insert(id)
        out.append(ev)
    }
    return out
}

func describe(_ ev: EKEvent) -> String {
    let rule = ev.recurrenceRules?.first.map { r -> String in
        String(describing: r).components(separatedBy: "RRULE ").last ?? "yes"
    } ?? "none"
    return """
        \(stampFmt.string(from: ev.startDate))-\(localFmt.string(from: ev.endDate).suffix(5)) \
        | \(ev.title ?? "") | alarms=\(ev.alarms?.count ?? 0) | rrule=\(rule) \
        | id=\(ev.eventIdentifier ?? "?")
        """
}

// MARK: - Subcommands

func cmdCalendars(_ store: EKEventStore) {
    for cal in store.calendars(for: .event).sorted(by: { $0.title < $1.title }) {
        let writable = cal.allowsContentModifications ? "rw" : "ro"
        print("\(cal.title)\t[\(writable)]\t\(cal.source.title)")
    }
}

func cmdList(_ args: Args, _ store: EKEventStore) {
    let cal = calendar(named: args.require("calendar"), source: args.one("source"), in: store)
    let from = parseLocal(args.require("from"), what: "--from")
    let to = parseLocal(args.require("to"), what: "--to")
    let events = uniqueEvents(in: cal, store: store, from: from, to: to, title: args.one("title"))
    if events.isEmpty { print("no matching events") }
    events.forEach { print(describe($0)) }
}

func cmdCreate(_ args: Args, _ store: EKEventStore) {
    let cal = calendar(named: args.require("calendar"), source: args.one("source"), in: store)
    guard cal.allowsContentModifications else { die("calendar \"\(cal.title)\" is read-only") }
    let title = args.require("title")
    let allDay = args.has("all-day")

    // Build the list of (start, end) pairs.
    var spans: [(Date, Date)] = []
    if let datesRaw = args.one("dates") {
        let time = args.one("time") ?? "00:00"
        guard let minutes = Int(args.one("duration") ?? "") else {
            die("--dates requires --duration MIN")
        }
        for day in datesRaw.split(separator: ",") {
            let start = parseLocal("\(day.trimmingCharacters(in: .whitespaces)) \(time)", what: "--dates entry")
            spans.append((start, start.addingTimeInterval(Double(minutes) * 60)))
        }
    } else {
        let start = parseLocal(args.require("start"), what: "--start")
        let end: Date
        if let e = args.one("end") {
            end = parseLocal(e, what: "--end")
        } else if let minutes = Int(args.one("duration") ?? "") {
            end = start.addingTimeInterval(Double(minutes) * 60)
        } else {
            die("--start requires --end or --duration")
        }
        spans.append((start, end))
    }

    if args.has("rrule") && spans.count > 1 {
        die("--rrule works with a single --start, not with --dates")
    }

    let alarms = args.all("alarm-minutes").compactMap(Int.init).map {
        EKAlarm(relativeOffset: Double(-$0) * 60)
    }

    for (start, end) in spans {
        let ev = EKEvent(eventStore: store)
        ev.calendar = cal
        ev.title = title
        ev.startDate = start
        ev.endDate = end
        ev.isAllDay = allDay
        ev.notes = args.one("notes")
        ev.location = args.one("location")
        ev.alarms = alarms.isEmpty ? nil : alarms
        if let rrule = args.one("rrule") { ev.recurrenceRules = [parseRRule(rrule)] }

        do {
            try store.save(ev, span: .thisEvent, commit: true)
            print("created \(describe(ev))")
        } catch {
            die("create failed for \(stampFmt.string(from: start)): \(error.localizedDescription)")
        }
    }
}

func cmdDelete(_ args: Args, _ store: EKEventStore) {
    let cal = calendar(named: args.require("calendar"), source: args.one("source"), in: store)
    var targets: [EKEvent] = []
    let ids = args.all("id")
    if !ids.isEmpty {
        for id in ids {
            guard let ev = store.event(withIdentifier: id) else { die("no event with id \(id)") }
            guard ev.calendar.calendarIdentifier == cal.calendarIdentifier else {
                die("event \(id) is not on calendar \"\(cal.title)\"")
            }
            // The series id resolves to the first occurrence, so `thisEvent`
            // would silently remove that one, not the occurrence meant.
            if ev.hasRecurrenceRules && args.one("span") == "thisEvent" {
                die("\(id) is a recurring series; use `skip --id \(id) --dates ...` to remove single occurrences")
            }
            targets.append(ev)
        }
    } else {
        let title = args.require("title")
        let from = parseLocal(args.require("from"), what: "--from")
        let to = parseLocal(args.require("to"), what: "--to")
        targets = uniqueEvents(in: cal, store: store, from: from, to: to, title: title)
        if targets.isEmpty { print("no matching events"); return }
    }

    for match in targets {
        // A series is removed wholesale from its first occurrence; starting
        // from a mid-series occurrence would leave the earlier ones behind.
        // Single occurrences are `skip`'s job.
        let ev = match.hasRecurrenceRules
            ? (match.eventIdentifier.flatMap { store.event(withIdentifier: $0) } ?? match)
            : match
        let label = describe(ev)
        let span: EKSpan = ev.hasRecurrenceRules ? .futureEvents : .thisEvent
        do {
            try store.remove(ev, span: span, commit: true)
            print("deleted (\(ev.hasRecurrenceRules ? "whole series" : "one-off")) \(label)")
        } catch {
            die("delete failed for \(label): \(error.localizedDescription)")
        }
    }
}

/// Removes individual occurrences of recurring events (an exception on the
/// series) and leaves the series itself intact. Resolves every target before
/// touching anything, so a typo'd date aborts the whole run with no changes.
func cmdSkip(_ args: Args, _ store: EKEventStore) {
    let cal = calendar(named: args.require("calendar"), source: args.one("source"), in: store)
    let ids = Set(args.all("id"))
    let titles = Set(args.all("title"))
    guard !ids.isEmpty || !titles.isEmpty else { die("skip requires --id or --title (both repeatable)") }

    // One window per --dates day (each must match something), or a single
    // --from/--to window (may legitimately match nothing).
    var windows: [(from: Date, to: Date, label: String, mustMatch: Bool)] = []
    if let datesRaw = args.one("dates") {
        for raw in datesRaw.split(separator: ",") {
            let day = raw.trimmingCharacters(in: .whitespaces)
            let from = parseLocal(day, what: "--dates entry")
            windows.append((from, Calendar.current.date(byAdding: .day, value: 1, to: from)!, day, true))
        }
    } else {
        let from = parseLocal(args.require("from"), what: "--from")
        let to = parseLocal(args.require("to"), what: "--to")
        guard to > from else { die("--to must be after --from") }
        windows.append((from, to, "\(dayFmt.string(from: from))..\(dayFmt.string(from: to))", false))
    }

    let matchesFilter: (EKEvent) -> Bool = {
        ids.contains($0.eventIdentifier ?? "") || titles.contains($0.title ?? "")
    }
    func occurrences(from: Date, to: Date) -> [EKEvent] {
        store.events(matching: store.predicateForEvents(withStart: from, end: to, calendars: [cal]))
            .filter { $0.startDate >= from && $0.startDate < to && matchesFilter($0) }
            .sorted { $0.startDate < $1.startDate }
    }

    var targets: [(id: String, start: Date, label: String)] = []
    var problems: [String] = []
    for w in windows {
        let hits = occurrences(from: w.from, to: w.to)
        if hits.isEmpty && w.mustMatch { problems.append("no matching occurrence on \(w.label)") }
        for ev in hits {
            guard ev.hasRecurrenceRules, let id = ev.eventIdentifier else {
                problems.append("one-off, not an occurrence (use delete): \(describe(ev))")
                continue
            }
            targets.append((id, ev.startDate, describe(ev)))
        }
    }
    if !problems.isEmpty { die("nothing changed:\n  " + problems.joined(separator: "\n  ")) }
    if targets.isEmpty { print("no matching occurrences"); return }

    if args.has("dry-run") {
        targets.forEach { print("would skip \($0.label)") }
        return
    }

    for t in targets {
        // Re-fetch right before removal: an occurrence object fetched before
        // an earlier removal on the same series can be stale.
        let fresh = occurrences(from: t.start, to: t.start.addingTimeInterval(1))
            .first { $0.eventIdentifier == t.id }
        guard let ev = fresh else { die("occurrence vanished before removal: \(t.label)") }
        do {
            try store.remove(ev, span: .thisEvent, commit: true)
            print("skipped \(t.label)")
        } catch {
            die("skip failed for \(t.label): \(error.localizedDescription)")
        }
    }

    store.reset()
    let leftover = targets.filter { t in
        occurrences(from: t.start, to: t.start.addingTimeInterval(1)).contains { $0.eventIdentifier == t.id }
    }
    if !leftover.isEmpty {
        die("still present after skip:\n  " + leftover.map(\.label).joined(separator: "\n  "))
    }
    print("verified: \(targets.count) occurrence(s) gone, series kept")
}

func cmdStripAlarms(_ args: Args, _ store: EKEventStore) {
    let cal = calendar(named: args.require("calendar"), source: args.one("source"), in: store)
    let from = parseLocal(args.require("from"), what: "--from")
    let to = parseLocal(args.require("to"), what: "--to")
    var changed = 0
    for ev in uniqueEvents(in: cal, store: store, from: from, to: to, title: args.one("title")) {
        guard let existing = ev.alarms, !existing.isEmpty else { continue }
        ev.alarms = nil
        do {
            try store.save(ev, span: .futureEvents, commit: true)
            changed += 1
            print("stripped \(existing.count) alarm(s) \(describe(ev))")
        } catch {
            die("strip failed for \(describe(ev)): \(error.localizedDescription)")
        }
    }
    if changed == 0 { print("no events with alarms in range") }
}

// MARK: - Entry point

let argv = Array(CommandLine.arguments.dropFirst())
guard let sub = argv.first, !sub.hasPrefix("--") else {
    die("usage: calendar-ek <calendars|list|create|delete|skip|strip-alarms> [flags] (see header comment)")
}
let args = Args(Array(argv.dropFirst()))
let store = grantedStore()

switch sub {
case "calendars": cmdCalendars(store)
case "list": cmdList(args, store)
case "create": cmdCreate(args, store)
case "delete": cmdDelete(args, store)
case "skip": cmdSkip(args, store)
case "strip-alarms": cmdStripAlarms(args, store)
default: die("unknown subcommand \"\(sub)\"")
}
