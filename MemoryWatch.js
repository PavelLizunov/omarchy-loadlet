// Session-local evidence, bounded to 121 snapshots of at most 256 process identities.
function measurement(value) {
  var n = Number(value)
  return typeof value === "string" && value !== "" && isFinite(n) && n >= 0 ? n : null
}
function parse(raw) {
  var lines = String(raw).split("\n")
  if (lines[0] !== "schema\tactivity-memory-watch\t1") return null
  var frame = {system: {}, processes: {}, pressure: {some: null, full: null}}
  var count = 0
  for (var i = 1; i < lines.length; ++i) {
    var f = lines[i].split("\t")
    if (f[0] === "sample" && f.length === 5) {
      frame.time = measurement(f[1]); frame.mono = measurement(f[2]); frame.uptime = measurement(f[3]); frame.boot = f[4]
    } else if (f[0] === "memory" && f.length === 3) frame.system[f[1]] = measurement(f[2])
    else if (f[0] === "pressure" && (f[1] === "some" || f[1] === "full")) frame.pressure[f[1]] = measurement(f[2])
    else if (f[0] === "coverage" && f.length === 8) {
      frame.coverage = {observed: measurement(f[1]), retained: measurement(f[2]), pss: measurement(f[3]),
        unavailable: measurement(f[4]), zombies: measurement(f[5]), limited: f[6] === "1", durationMs: measurement(f[7])}
    } else if (f[0] === "process" && f.length === 11) {
      if (++count > 256 || !/^[1-9][0-9]*$/.test(f[1]) || !/^[1-9][0-9]*$/.test(f[2])) return null
      var key = frame.boot + ":" + f[1] + ":" + f[2]
      frame.processes[key] = {key: key, pid: f[1], startTicks: f[2], parent: f[3], state: f[4],
        rss: measurement(f[5]), anon: measurement(f[6]), swap: measurement(f[7]),
        pss: measurement(f[8]), uss: measurement(f[9]), name: f[10]}
    }
  }
  if (!(frame.time > 0 && frame.mono > 0 && frame.uptime > 0 && frame.boot)
      || !frame.coverage || !(frame.system.MemTotal > 0)) return null
  var s = frame.system
  s.used = s.MemAvailable !== null && s.MemAvailable !== undefined ? Math.max(0, s.MemTotal - s.MemAvailable) : null
  s.cache = s.Cached !== null && s.Cached !== undefined && s.SReclaimable !== null && s.SReclaimable !== undefined
    ? s.Cached + s.SReclaimable : null
  s.swap = s.SwapTotal !== null && s.SwapTotal !== undefined && s.SwapFree !== null && s.SwapFree !== undefined
    ? Math.max(0, s.SwapTotal - s.SwapFree) : null
  return frame
}
function append(frames, frame, interrupted) {
  var last = frames.length ? frames[frames.length - 1] : null
  frame.breakBefore = !!interrupted || !!(last && (frame.boot !== last.boot || frame.mono <= last.mono
    || frame.mono - last.mono > 75 || Math.abs((frame.time-last.time)-(frame.mono-last.mono)) > 5
    || Math.abs((frame.uptime-last.uptime)-(frame.mono-last.mono)) > 5))
  return frames.concat([frame]).slice(-121)
}
function series(frames, field, key) {
  var result = [], gap = false
  frames.forEach(function(frame) {
    // A wall-clock reversal starts a new chart segment rather than folding the axis.
    if (result.length && frame.time <= result[result.length-1].time) result = []
    var source = key ? frame.processes[key] : frame.system
    var value = source ? source[field] : null
    if (value === null || value === undefined) { gap = true; return }
    result.push({time: frame.time, value: value / 1024, breakBefore: gap || frame.breakBefore})
    gap = false
  })
  return result
}
function summaries(frames) {
  if (!frames.length) return []
  var latest = frames[frames.length-1]
  return Object.keys(latest.processes).map(function(key) {
    var current = latest.processes[key], end = frames.length-1, begin = end, up = 0
    while (begin > 0 && !frames[begin].breakBefore) {
      var prev = frames[begin-1].processes[key], next = frames[begin].processes[key]
      if (!prev || prev.anon === null || next.anon === null) break
      if (next.anon - prev.anon >= 1024) ++up
      --begin
    }
    var first = frames[begin].processes[key]
    var span = latest.mono - frames[begin].mono
    var growth = current.anon !== null && first.anon !== null ? current.anon - first.anon : null
    var samples = end - begin + 1
    var peak = current.anon
    for (var i = begin; i <= end; ++i) {
      var a = frames[i].processes[key].anon
      if (a !== null) peak = peak === null ? a : Math.max(peak, a)
    }
    return Object.assign({}, current, {baseline: first.anon, growth: growth, peak: peak, span: span,
      samples: samples, rate: span > 0 && growth !== null ? growth / (span/60) : null,
      candidate: span >= 600 && samples >= 12 && growth >= 65536 && growth >= Math.max(1, first.anon) * 0.25
        && up / Math.max(1, samples-1) >= 0.7})
  }).sort(function(a,b) {
    return Number(b.candidate)-Number(a.candidate) || (b.growth || 0)-(a.growth || 0) || (b.rss || 0)-(a.rss || 0)
  })
}
function report(frames, rows, selectedKey) {
  var included = rows.slice(0,10)
  var selected = rows.find(function(row) { return row.key === selectedKey })
  if (selected && !included.some(function(row) { return row.key === selectedKey })) included[9] = selected
  return JSON.stringify({schema: 1, scope: "Local memory observation; growth candidates are not proven leaks. KiB unless stated. No argv or environment.",
    limits: "Up to 256 largest RSS processes; PSS/USS attempted for 32. Gaps reset comparisons. Session is not persisted. No workload matching or allocation tracing.",
    candidateRule: "Contiguous >=10min, >=12 samples, anonymous RSS growth >=64MiB and >=25%, >=70% steps grow by >=1MiB.",
    system: frames.map(function(f) { return {time:f.time, mono:f.mono, uptime:f.uptime, boot:f.boot, breakBefore:f.breakBefore,
      memory:f.system, pressure:f.pressure, coverage:f.coverage} }),
    processes: included.map(function(r) { return {summary:r, samples:frames.map(function(f) {
      return {time:f.time, breakBefore:f.breakBefore, values:f.processes[r.key] || null}
    })} })})
}
