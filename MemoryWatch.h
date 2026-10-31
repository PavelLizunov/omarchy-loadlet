// Included in the sampler namespace. Explicit snapshots only, no retained OS handles.
class MemoryWatchCollector {
public:
  explicit MemoryWatchCollector(Paths paths) : paths_(std::move(paths)) {}

  void Collect(std::ostream &output) const {
    const auto begin = Clock::now();
    const auto deadline = begin + std::chrono::milliseconds(300);
    const auto system = Values(Join(paths_.proc, "meminfo"));
    const auto boot = ReadLine(Join(paths_.proc, "sys/kernel/random/boot_id"));
    const auto uptime = ParseDouble(UptimeSample(paths_));
    const auto wall = std::chrono::duration<double>(std::chrono::system_clock::now().time_since_epoch()).count();
    const auto mono = std::chrono::duration<double>(begin.time_since_epoch()).count();
    output << "schema\tactivity-memory-watch\t1\n"
           << "sample\t" << std::fixed << std::setprecision(3) << wall << '\t' << mono
           << '\t' << uptime.value_or(0) << '\t' << Sanitize(boot.value_or("")) << '\n';
    for (const auto *key : {"MemTotal", "MemAvailable", "Cached", "SReclaimable", "AnonPages",
                            "Shmem", "SUnreclaim", "SwapTotal", "SwapFree"})
      output << "memory\t" << key << '\t' << Get(system, key) << '\n';
    const auto pressure = ReadText(Join(paths_.proc, "pressure/memory"));
    if (pressure) {
      std::istringstream lines(*pressure); std::string line;
      while (std::getline(lines, line)) {
        const auto fields = SplitWhitespace(line);
        if (fields.size() > 1 && (fields[0] == "some" || fields[0] == "full") && StartsWith(fields[1], "avg10="))
          output << "pressure\t" << fields[0] << '\t' << ParseDouble(fields[1].substr(6)).value_or(-1) << '\n';
      }
    }

    std::vector<Row> rows;
    std::size_t scanned = 0, unavailable = 0, zombies = 0;
    bool limited = false;
    DIR *directory = opendir(paths_.proc.c_str());
    if (!directory) limited = true;
    while (directory) {
      auto *entry = readdir(directory);
      if (!entry) break;
      const std::string name(entry->d_name);
      if (!IsDigits(name)) continue;
      if (++scanned > 4096 || Clock::now() >= deadline) { limited = true; break; }
      const auto path = Join(paths_.proc, name);
      const auto first = Identity(path);
      if (!first) { ++unavailable; continue; }
      if (first->kernel) continue;
      const auto values = Values(Join(path, "status"));
      const auto last = Identity(path);
      if (!last || first->start != last->start || Get(values, "VmRSS") < 0) {
        if (last && first->start == last->start && last->state == "Z") ++zombies;
        else ++unavailable;
        continue;
      }
      if (last->state == "Z") { ++zombies; continue; }
      rows.push_back({name, last->start, last->name, last->state, last->parent,
                      Get(values, "VmRSS"), Get(values, "RssAnon"), Get(values, "VmSwap"), -1, -1});
    }
    if (directory) closedir(directory);
    std::sort(rows.begin(), rows.end(), [](const Row &a, const Row &b) {
      return a.rss != b.rss ? a.rss > b.rss : a.pid < b.pid;
    });
    const auto observed = rows.size();
    if (rows.size() > 256) { rows.resize(256); limited = true; }
    std::size_t measured = 0;
    // PSS/USS walks page tables: cap admission to 32 largest RSS processes per snapshot.
    for (std::size_t i = 0; i < std::min<std::size_t>(32, rows.size()); ++i) {
      if (Clock::now() >= deadline) { limited = true; break; }
      auto &row = rows[i];
      const auto path = Join(paths_.proc, row.pid);
      const auto first = Identity(path);
      if (!first || first->start != row.start) continue;
      const auto values = Values(Join(path, "smaps_rollup"));
      const auto last = Identity(path);
      if (!last || last->start != row.start) continue;
      row.pss = Get(values, "Pss");
      const auto clean = Get(values, "Private_Clean"), dirty = Get(values, "Private_Dirty");
      if (clean >= 0 && dirty >= 0) row.uss = clean + dirty;
      if (row.pss >= 0) ++measured;
    }
    for (const auto &row : rows)
      output << "process\t" << row.pid << '\t' << row.start << '\t' << row.parent << '\t'
             << row.state << '\t' << row.rss << '\t' << row.anon << '\t' << row.swap << '\t'
             << row.pss << '\t' << row.uss << '\t' << row.name << '\n';
    output << "coverage\t" << observed << '\t' << rows.size() << '\t' << measured << '\t'
           << unavailable << '\t' << zombies << '\t' << (limited ? 1 : 0) << '\t'
           << std::chrono::duration<double, std::milli>(Clock::now() - begin).count() << '\n';
  }

private:
  Paths paths_;
  struct IdentityRow { std::string start, name, state, parent; bool kernel; };
  struct Row {
    std::string pid, start, name, state, parent;
    std::int64_t rss, anon, swap, pss, uss;
  };
  using Counters = std::unordered_map<std::string, std::int64_t>;
  static Counters Values(const std::string &path) {
    Counters result;
    const auto raw = ReadText(path);
    if (!raw) return result;
    std::istringstream lines(*raw); std::string line;
    while (std::getline(lines, line)) {
      const auto fields = SplitWhitespace(line);
      if (fields.size() != 3 || fields[2] != "kB" || fields[0].back() != ':') continue;
      const auto value = ParseUnsigned(fields[1]);
      if (value && *value <= (std::uint64_t{1} << 50))
        result[fields[0].substr(0, fields[0].size() - 1)] = static_cast<std::int64_t>(*value);
    }
    return result;
  }
  static std::int64_t Get(const Counters &values, const std::string &key) {
    const auto found = values.find(key);
    return found == values.end() ? -1 : found->second;
  }
  static std::optional<IdentityRow> Identity(const std::string &path) {
    const auto raw = ReadLine(Join(path, "stat"));
    if (!raw) return std::nullopt;
    const auto begin = raw->find('('), end = raw->rfind(") ");
    if (begin == std::string::npos || end == std::string::npos || begin >= end) return std::nullopt;
    const auto fields = SplitWhitespace(raw->substr(end + 2));
    if (fields.size() < 20 || !ParseUnsigned(fields[19]) || !ParseUnsigned(fields[6])) return std::nullopt;
    return IdentityRow{fields[19], Sanitize(raw->substr(begin + 1, end - begin - 1)).substr(0, 64),
                       fields[0], fields[1], (ParseUnsigned(fields[6]).value() & kKernelThreadFlag) != 0};
  }
};
