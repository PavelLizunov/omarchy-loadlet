#include <algorithm>
#include <array>
#include <cctype>
#include <cerrno>
#include <chrono>
#include <climits>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <dirent.h>
#include <dlfcn.h>
#include <fstream>
#include <fcntl.h>
#include <ctime>
#include <sys/file.h>
#include <poll.h>
#include <glob.h>
#include <iomanip>
#include <iostream>
#include <iterator>
#include <limits>
#include <mntent.h>
#include <optional>
#include <sstream>
#include <string>
#include <string_view>
#include <sys/stat.h>
#include <sys/statvfs.h>
#include <sys/prctl.h>
#include <signal.h>
#include <sys/types.h>
#include <unistd.h>
#include <unordered_map>
#include <unordered_set>
#include <utility>
#include <vector>

namespace {

using Clock = std::chrono::steady_clock;

constexpr std::uint64_t kKernelThreadFlag = 0x00200000;
constexpr std::size_t kFrameLimit = 262144;
bool input_overflow = false;

// Enforce the transport budget before emission to Quickshell's SplitParser.
class FrameBuffer : public std::streambuf {
public:
  std::string data;
  bool exceeded = false;
protected:
  std::streamsize xsputn(const char *text, std::streamsize count) override {
    if (count < 0 || static_cast<std::size_t>(count) > kFrameLimit - data.size()) {
      exceeded = true;
      return 0;
    }
    data.append(text, static_cast<std::size_t>(count));
    return count;
  }
  int_type overflow(int_type ch) override {
    if (traits_type::eq_int_type(ch, traits_type::eof())) return traits_type::not_eof(ch);
    const char value = traits_type::to_char_type(ch);
    return xsputn(&value, 1) == 1 ? ch : traits_type::eof();
  }
};

struct Paths {
  std::string proc;
  std::string sys;
  std::string passwd;
  std::string root;
  std::string udev_data;
  std::string nvidia_fixture;
  std::string statfs_fixture;
};

std::string EnvOr(const char *name, const char *fallback) {
  const char *value = std::getenv(name);
  return value && *value ? value : fallback;
}

Paths UserPaths() {
  return {
      EnvOr("OMARCHY_SYSTEM_STATS_PROC_PATH", "/proc"),
      EnvOr("OMARCHY_SYSTEM_STATS_SYS_PATH", "/sys"),
      EnvOr("OMARCHY_SYSTEM_STATS_PASSWD_PATH", "/etc/passwd"),
      EnvOr("OMARCHY_SYSTEM_STATS_ROOT_PATH", "/"),
      EnvOr("OMARCHY_SYSTEM_STATS_UDEV_DATA_PATH", "/run/udev/data/+dmi:id"),
      EnvOr("OMARCHY_SYSTEM_STATS_NVIDIA_FIXTURE_PATH", ""),
      EnvOr("OMARCHY_SYSTEM_STATS_STATFS_FIXTURE_PATH", ""),
  };
}

std::string Join(const std::string &left, const std::string &right) {
  if (left.empty())
    return right;
  if (right.empty())
    return left;
  if (left.back() == '/')
    return left + (right.front() == '/' ? right.substr(1) : right);
  return left + (right.front() == '/' ? right : "/" + right);
}

bool IsDigits(std::string_view value) {
  return !value.empty() &&
         std::all_of(value.begin(), value.end(),
                     [](unsigned char ch) { return std::isdigit(ch); });
}

std::string Trim(std::string value) {
  const auto first = value.find_first_not_of(" \t\r\n");
  if (first == std::string::npos)
    return "";
  const auto last = value.find_last_not_of(" \t\r\n");
  return value.substr(first, last - first + 1);
}

std::string Sanitize(std::string value) {
  for (char &ch : value) {
    if (ch == '\t' || ch == '\r' || ch == '\n')
      ch = ' ';
  }
  return Trim(std::move(value));
}

std::string Lowercase(std::string value) {
  std::transform(value.begin(), value.end(), value.begin(),
                 [](unsigned char character) {
                   return static_cast<char>(std::tolower(character));
                 });
  return value;
}

bool StartsWith(std::string_view value, std::string_view prefix) {
  return value.size() >= prefix.size() &&
         value.substr(0, prefix.size()) == prefix;
}

bool EndsWith(std::string_view value, std::string_view suffix) {
  return value.size() >= suffix.size() &&
         value.substr(value.size() - suffix.size()) == suffix;
}

std::optional<std::string> ReadText(const std::string &path) {
  std::ifstream stream(path, std::ios::binary);
  if (!stream)
    return std::nullopt;
  std::string output;
  std::array<char, 4096> chunk{};
  while (stream) {
    stream.read(chunk.data(), chunk.size());
    const auto count = static_cast<std::size_t>(stream.gcount());
    if (count > kFrameLimit - output.size()) { input_overflow = true; return std::nullopt; }
    output.append(chunk.data(), count);
  }
  return output;
}

std::optional<std::string> ReadLine(const std::string &path) {
  std::ifstream stream(path);
  std::array<char, 8192> line{};
  if (!stream)
    return std::nullopt;
  stream.getline(line.data(), line.size());
  if (stream.fail() && !stream.eof()) {
    // Only a line that filled the buffer is an overflow; a read error (e.g. ENODATA
    // from an idle iwlwifi sensor) just means this file has no value.
    if (stream.gcount() == static_cast<std::streamsize>(line.size()) - 1) input_overflow = true;
    return std::nullopt;
  }
  return Trim(line.data());
}

std::optional<std::uint64_t> ParseUnsigned(std::string_view value,
                                           int base = 10) {
  if (value.empty() || base < 2 || base > 16 || value.front() == '-')
    return std::nullopt;
  std::size_t index = value.front() == '+' ? 1 : 0;
  if (base == 16 && value.size() >= index + 2 && value[index] == '0' &&
      (value[index + 1] == 'x' || value[index + 1] == 'X'))
    index += 2;
  if (index >= value.size())
    return std::nullopt;

  std::uint64_t parsed = 0;
  for (; index < value.size(); ++index) {
    const unsigned char character = value[index];
    unsigned int digit = 0;
    if (character >= '0' && character <= '9')
      digit = character - '0';
    else if (character >= 'a' && character <= 'f')
      digit = character - 'a' + 10;
    else if (character >= 'A' && character <= 'F')
      digit = character - 'A' + 10;
    else
      return std::nullopt;
    if (digit >= static_cast<unsigned int>(base) ||
        parsed > (std::numeric_limits<std::uint64_t>::max() - digit) /
                     static_cast<unsigned int>(base))
      return std::nullopt;
    parsed = parsed * static_cast<unsigned int>(base) + digit;
  }
  return parsed;
}

std::optional<double> ParseDouble(std::string_view value) {
  if (value.empty())
    return std::nullopt;
  std::string input(value);
  char *end = nullptr;
  errno = 0;
  const double parsed = std::strtod(input.c_str(), &end);
  if (errno || end == input.c_str() || *end != '\0' || !std::isfinite(parsed))
    return std::nullopt;
  return parsed;
}

std::optional<std::uint64_t> ReadUnsigned(const std::string &path) {
  const auto line = ReadLine(path);
  return line ? ParseUnsigned(*line) : std::nullopt;
}

std::string UptimeSample(const Paths &paths) {
  const auto line = ReadLine(Join(paths.proc, "uptime"));
  if (!line)
    return "0";
  std::istringstream fields(*line);
  std::string sample;
  fields >> sample;
  return ParseDouble(sample) ? sample : "0";
}

bool Exists(const std::string &path) {
  struct stat status{};
  return stat(path.c_str(), &status) == 0;
}

bool IsDirectory(const std::string &path) {
  struct stat status{};
  return stat(path.c_str(), &status) == 0 && S_ISDIR(status.st_mode);
}

std::vector<std::string> DirectoryNames(const std::string &path) {
  std::vector<std::string> names;
  DIR *directory = opendir(path.c_str());
  if (!directory)
    return names;
  while (dirent *entry = readdir(directory)) {
    std::string name(entry->d_name);
    if (name != "." && name != "..")
      names.push_back(std::move(name));
    if (names.size() >= 8192) { input_overflow = true; break; }
  }
  closedir(directory);
  return names;
}

std::vector<std::string> GlobPaths(const std::string &pattern) {
  glob_t matches{};
  std::vector<std::string> paths;
  if (glob(pattern.c_str(), GLOB_NOSORT, nullptr, &matches) == 0) {
    paths.reserve(matches.gl_pathc);
    for (std::size_t index = 0; index < matches.gl_pathc; ++index)
      paths.emplace_back(matches.gl_pathv[index]);
  }
  globfree(&matches);
  return paths;
}

std::string RealPath(const std::string &path) {
  std::array<char, PATH_MAX> resolved{};
  return realpath(path.c_str(), resolved.data()) ? resolved.data() : "";
}

std::string BaseName(const std::string &path) {
  const auto slash = path.find_last_of('/');
  return slash == std::string::npos ? path : path.substr(slash + 1);
}

std::vector<std::string> SplitWhitespace(const std::string &value) {
  std::istringstream stream(value);
  std::vector<std::string> fields;
  std::string field;
  while (stream >> field)
    fields.push_back(std::move(field));
  return fields;
}

std::unordered_set<int> ParseCpuList(const std::string &list) {
  std::unordered_set<int> cpus;
  const std::string value = Trim(list);
  std::size_t index = 0;
  while (index < value.size()) {
    if (value[index] == ',' || value[index] == ' ') {
      ++index;
      continue;
    }
    if (!std::isdigit(static_cast<unsigned char>(value[index]))) {
      ++index;
      continue;
    }
    int start = 0;
    while (index < value.size() &&
           std::isdigit(static_cast<unsigned char>(value[index]))) {
      if (start > 4096) return {};
      start = start * 10 + (value[index] - '0');
      ++index;
    }
    int end = start;
    if (index < value.size() && value[index] == '-') {
      ++index;
      end = 0;
      bool any = false;
      while (index < value.size() &&
             std::isdigit(static_cast<unsigned char>(value[index]))) {
        if (end > 4096) return {};
        end = end * 10 + (value[index] - '0');
        any = true;
        ++index;
      }
      if (!any)
        end = start;
    }
    if (end < start)
      std::swap(start, end);
    for (int cpu = start; cpu <= end && cpu < 4096; ++cpu)
      cpus.insert(cpu);
  }
  return cpus;
}

bool CpuListContains(const std::string &list, int cpu) {
  return ParseCpuList(list).count(cpu) != 0;
}

std::uint64_t PositiveEnv(const char *name, std::uint64_t fallback) {
  const char *value = std::getenv(name);
  if (!value)
    return fallback;
  const auto parsed = ParseUnsigned(value);
  return parsed && *parsed > 0 ? *parsed : fallback;
}

std::uint64_t SystemValue(int name, std::uint64_t fallback) {
  const long value = sysconf(name);
  return value > 0 ? static_cast<std::uint64_t>(value) : fallback;
}

class ResourceCollector {
public:
  explicit ResourceCollector(Paths paths) : paths_(std::move(paths)) {}

  void Collect(std::ostream &output) {
    DiscoverTopology();
    output << "schema\tactivity-resources\t1\n";
    output << "sample\t" << UptimeSample(paths_) << '\n';
    EmitMemorySpeed(output);
    EmitCpu(output);
    EmitCpuTopology(output);
    EmitMemory(output);
    EmitTasks(output);
    EmitNetwork(output);
    EmitDisks(output);
    EmitCpuFrequency(output);
  }

  void BarWidget(std::ostream &output) {
    std::ifstream stat_stream(Join(paths_.proc, "stat"));
    std::string line;
    if (std::getline(stat_stream, line)) {
      auto fields = SplitWhitespace(line);
      if (fields.size() >= 5 && fields[0] == "cpu") {
        std::uint64_t total = 0;
        for (std::size_t index = 1; index < fields.size() && index <= 8;
             ++index)
          total += ParseUnsigned(fields[index]).value_or(0);
        const auto idle =
            ParseUnsigned(fields[4]).value_or(0) +
            (fields.size() > 5 ? ParseUnsigned(fields[5]).value_or(0) : 0);
        output << "cpu\t" << idle << '\t' << total << '\n';
      }
    }

    auto memory = MemoryValues();
    const auto total = memory["MemTotal"];
    const auto available = memory["MemAvailable"];
    if (total > 0) {
      const double percent =
          static_cast<double>(total - std::min(total, available)) /
          static_cast<double>(total) * 100.0;
      output << "memory\t" << std::fixed << std::setprecision(2) << percent
             << "\n";
      output.unsetf(std::ios::floatfield);
    }

    const auto load = ReadLine(Join(paths_.proc, "loadavg"));
    if (load) {
      const auto fields = SplitWhitespace(*load);
      if (!fields.empty())
        output << "load\t" << fields[0] << '\n';
    }
  }

  // Icon-only request: no topology, per-process, GPU, disk or thermal reads.
  void Glance(std::ostream &output) const {
    output << "schema\tactivity-resources\t1\n";
    output << "sample\t" << UptimeSample(paths_) << '\n';
    const auto line = ReadLine(Join(paths_.proc, "stat"));
    if (line) {
      const auto fields = SplitWhitespace(*line);
      if (fields.size() >= 5 && fields[0] == "cpu") {
        std::uint64_t total = 0;
        for (std::size_t i = 1; i < fields.size() && i <= 8; ++i)
          total += ParseUnsigned(fields[i]).value_or(0);
        const auto idle = ParseUnsigned(fields[4]).value_or(0) +
            (fields.size() > 5 ? ParseUnsigned(fields[5]).value_or(0) : 0);
        output << "cpu\tcpu\t" << total << '\t' << idle << '\n';
      }
    }
    EmitMemory(output);
  }

private:
  struct BlockDevice {
    std::string name;
    std::string path;
  };

  struct CpuTopo {
    int id = -1;
    int core_id = -1;
    std::string cluster;
    std::string l2;
    std::string l3;
    std::string domain;
    std::string cls;
    std::uint64_t max_khz = 0;
    std::uint64_t capacity = 0;
  };

  Paths paths_;
  bool topology_discovered_ = false;
  Clock::time_point next_topology_{};
  bool memory_speed_checked_ = false;
  int memory_speed_mts_ = -1;
  std::vector<std::string> cpu_frequency_paths_;
  std::vector<BlockDevice> block_devices_;
  std::vector<CpuTopo> cpu_topo_;

  void DiscoverTopology() {
    if (topology_discovered_ && Clock::now() < next_topology_)
      return;
    topology_discovered_ = true;
    next_topology_ = Clock::now() + std::chrono::seconds(30);
    cpu_frequency_paths_.clear();
    block_devices_.clear();

    const std::string frequency_root =
        Join(paths_.sys, "devices/system/cpu/cpufreq");
    for (const auto &name : DirectoryNames(frequency_root)) {
      if (!StartsWith(name, "policy") ||
          !IsDigits(std::string_view(name).substr(6)))
        continue;
      const std::string path =
          Join(Join(frequency_root, name), "scaling_cur_freq");
      if (Exists(path))
        cpu_frequency_paths_.push_back(path);
    }

    const std::string block_root = Join(paths_.sys, "class/block");
    for (const auto &name : DirectoryNames(block_root)) {
      if (StartsWith(name, "loop") || StartsWith(name, "ram") ||
          StartsWith(name, "zram"))
        continue;
      const std::string path = Join(block_root, name);
      if (Exists(Join(path, "partition")))
        continue;
      if (!Exists(Join(path, "device/uevent")))
        continue;
      block_devices_.push_back({name, path});
    }
    std::sort(block_devices_.begin(), block_devices_.end(),
              [](const BlockDevice &left, const BlockDevice &right) {
                return left.name < right.name;
              });

    DiscoverCpuTopology();
  }

  static std::string CacheSharedList(const std::string &cpu_path, const char *level) {
    const std::string cache = Join(cpu_path, "cache");
    for (const auto &name : DirectoryNames(cache)) {
      if (!StartsWith(name, "index"))
        continue;
      const std::string index = Join(cache, name);
      if (ReadLine(Join(index, "level")).value_or("") != level)
        continue;
      if (ReadLine(Join(index, "type")).value_or("") != "Unified")
        continue;
      return ReadLine(Join(index, "shared_cpu_list")).value_or("");
    }
    return "";
  }

  void DiscoverCpuTopology() {
    cpu_topo_.clear();
    const std::string cpu_root = Join(paths_.sys, "devices/system/cpu");
    const std::string core_list =
        ReadLine(Join(paths_.sys, "devices/cpu_core/cpus")).value_or("");
    const std::string atom_list =
        ReadLine(Join(paths_.sys, "devices/cpu_atom/cpus")).value_or("");
    const bool intel_hybrid = !core_list.empty() || !atom_list.empty();

    for (const auto &name : DirectoryNames(cpu_root)) {
      if (!StartsWith(name, "cpu") || !IsDigits(std::string_view(name).substr(3)))
        continue;
      const int id = static_cast<int>(ParseUnsigned(name.substr(3)).value_or(4096));
      if (id >= 4096)
        continue;
      const std::string path = Join(cpu_root, name);
      const std::string topo = Join(path, "topology");
      if (!IsDirectory(topo))
        continue;
      if (Exists(Join(path, "online")) &&
          ReadLine(Join(path, "online")).value_or("1") == "0")
        continue;

      CpuTopo cpu;
      cpu.id = id;
      cpu.core_id = static_cast<int>(
          ParseUnsigned(ReadLine(Join(topo, "core_id")).value_or("")).value_or(id));
      cpu.cluster = ReadLine(Join(topo, "cluster_cpus_list")).value_or("");
      if (cpu.cluster.empty())
        cpu.cluster = std::to_string(id);
      cpu.l2 = CacheSharedList(path, "2");
      cpu.l3 = CacheSharedList(path, "3");
      cpu.domain = !cpu.l3.empty() ? cpu.l3 : (!cpu.l2.empty() ? cpu.l2 : cpu.cluster);
      cpu.max_khz =
          ParseUnsigned(ReadLine(Join(path, "cpufreq/cpuinfo_max_freq")).value_or(""))
              .value_or(0);
      cpu.capacity =
          ParseUnsigned(ReadLine(Join(path, "cpu_capacity")).value_or("")).value_or(0);
      cpu_topo_.push_back(std::move(cpu));
    }

    std::sort(cpu_topo_.begin(), cpu_topo_.end(),
              [](const CpuTopo &left, const CpuTopo &right) { return left.id < right.id; });

    std::unordered_set<std::string> p_l3;
    for (const auto &cpu : cpu_topo_) {
      if (intel_hybrid && CpuListContains(core_list, cpu.id) && !cpu.l3.empty())
        p_l3.insert(cpu.l3);
    }

    for (auto &cpu : cpu_topo_) {
      if (intel_hybrid && CpuListContains(core_list, cpu.id)) {
        cpu.cls = "performance";
        continue;
      }
      if (intel_hybrid && CpuListContains(atom_list, cpu.id)) {
        cpu.cls = (cpu.l3.empty() || p_l3.count(cpu.l3) == 0) ? "lowpower"
                                                              : "efficiency";
        continue;
      }
    }

    ClassifyUnlabeledCpus();
  }

  void ClassifyUnlabeledCpus() {
    std::vector<std::uint64_t> keys;
    keys.reserve(cpu_topo_.size());
    bool any_capacity = false;
    for (const auto &cpu : cpu_topo_) {
      if (!cpu.cls.empty())
        continue;
      if (cpu.capacity > 0)
        any_capacity = true;
      keys.push_back(cpu.capacity > 0 ? cpu.capacity : cpu.max_khz);
    }
    if (keys.empty())
      return;

    std::sort(keys.begin(), keys.end());
    keys.erase(std::unique(keys.begin(), keys.end()), keys.end());
    std::vector<std::uint64_t> groups;
    for (const auto key : keys) {
      if (groups.empty() || key > groups.back() * 112 / 100)
        groups.push_back(key);
    }
    if (groups.size() <= 1) {
      for (auto &cpu : cpu_topo_)
        if (cpu.cls.empty())
          cpu.cls = "performance";
      return;
    }

    const std::uint64_t high = groups.back();
    const std::uint64_t low = groups.front();
    for (auto &cpu : cpu_topo_) {
      if (!cpu.cls.empty())
        continue;
      const std::uint64_t key = any_capacity && cpu.capacity > 0 ? cpu.capacity
                                                                : cpu.max_khz;
      std::uint64_t nearest = groups[0];
      auto distance = [](std::uint64_t left, std::uint64_t right) {
        return left > right ? left - right : right - left;
      };
      for (const auto group : groups) {
        if (distance(key, group) < distance(key, nearest))
          nearest = group;
      }
      if (nearest == high)
        cpu.cls = "performance";
      else if (nearest == low && groups.size() >= 3)
        cpu.cls = "lowpower";
      else
        cpu.cls = "efficiency";
    }
  }

  void EmitCpuTopology(std::ostream &output) const {
    if (cpu_topo_.empty())
      return;
    for (const auto &cpu : cpu_topo_) {
      output << "cpu-topo\t" << cpu.id << '\t'
             << (cpu.cls.empty() ? "performance" : cpu.cls) << '\t' << cpu.domain
             << '\t' << cpu.cluster << '\t' << cpu.core_id << '\t' << cpu.max_khz
             << '\n';
    }
  }

  void EmitCpu(std::ostream &output) const {
    std::ifstream stream(Join(paths_.proc, "stat"));
    std::string line;
    while (std::getline(stream, line)) {
      const auto fields = SplitWhitespace(line);
      if (fields.empty() || !StartsWith(fields[0], "cpu"))
        break;
      if (fields[0] != "cpu" &&
          !IsDigits(std::string_view(fields[0]).substr(3)))
        break;
      std::uint64_t total = 0;
      std::array<std::uint64_t, 8> counters{};
      for (std::size_t index = 0; index < counters.size(); ++index) {
        if (index + 1 < fields.size())
          counters[index] = ParseUnsigned(fields[index + 1]).value_or(0);
        total += counters[index];
      }
      output << "cpu\t" << fields[0] << '\t' << total << '\t'
             << counters[3] + counters[4] << '\n';
    }
  }

  std::unordered_map<std::string, std::uint64_t> MemoryValues() const {
    std::unordered_map<std::string, std::uint64_t> values;
    std::ifstream stream(Join(paths_.proc, "meminfo"));
    std::string line;
    while (std::getline(stream, line)) {
      std::istringstream fields(line);
      std::string key;
      std::uint64_t value = 0;
      if (!(fields >> key >> value))
        continue;
      if (!key.empty() && key.back() == ':')
        key.pop_back();
      values[key] = value;
    }
    return values;
  }

  void EmitMemory(std::ostream &output) const {
    const auto values = MemoryValues();
    const auto get = [&values](const char *key) {
      const auto found = values.find(key);
      return found == values.end() ? std::uint64_t{0} : found->second;
    };
    output << "memory\t" << get("MemTotal") << '\t' << get("MemAvailable")
           << '\t' << get("SwapTotal") << '\t' << get("SwapFree") << '\t'
           << get("Cached") + get("SReclaimable") << '\n';
  }

  void EmitMemorySpeed(std::ostream &output) {
    if (!memory_speed_checked_) {
      memory_speed_checked_ = true;
      int configured = 0;
      int rated = 0;
      std::ifstream stream(paths_.udev_data);
      std::string line;
      while (std::getline(stream, line)) {
        if (StartsWith(line, "E:"))
          line.erase(0, 2);
        const auto equal = line.find('=');
        if (equal == std::string::npos)
          continue;
        const std::string key = line.substr(0, equal);
        const std::string value = line.substr(equal + 1);
        int candidate = 0;
        if (EndsWith(key, "_SPEED_MTS")) {
          candidate = static_cast<int>(ParseUnsigned(value).value_or(0));
        } else if (EndsWith(key, "_SPEED_GTS")) {
          candidate = static_cast<int>(
              std::lround(ParseDouble(value).value_or(0) * 1000.0));
        }
        if (candidate <= 0 || !StartsWith(key, "MEMORY_DEVICE_"))
          continue;
        if (key.find("_CONFIGURED_SPEED_") != std::string::npos) {
          if (configured == 0 || candidate < configured)
            configured = candidate;
        } else if (key.find("_SPEED_") != std::string::npos) {
          if (rated == 0 || candidate < rated)
            rated = candidate;
        }
      }
      memory_speed_mts_ =
          configured > 0 ? configured : (rated > 0 ? rated : -1);
    }
    if (memory_speed_mts_ > 0)
      output << "frequency\tmemory\t" << memory_speed_mts_ << "\tMT/s\n";
  }

  void EmitTasks(std::ostream &output) const {
    const auto line = ReadLine(Join(paths_.proc, "loadavg"));
    if (!line)
      return;
    const auto fields = SplitWhitespace(*line);
    if (fields.size() < 4)
      return;
    const auto slash = fields[3].find('/');
    if (slash == std::string::npos)
      return;
    output << "tasks\t" << fields[3].substr(0, slash) << '\t'
           << fields[3].substr(slash + 1) << '\n';
  }

  std::string DefaultInterface() const {
    std::ifstream stream(Join(paths_.proc, "net/route"));
    std::string line;
    std::getline(stream, line);
    std::string selected;
    std::uint64_t selected_metric = std::numeric_limits<std::uint64_t>::max();
    while (std::getline(stream, line)) {
      const auto fields = SplitWhitespace(line);
      if (fields.size() < 8 || fields[1] != "00000000" ||
          fields[7] != "00000000")
        continue;
      const auto flags = ParseUnsigned(fields[3], 16);
      const auto metric = ParseUnsigned(fields[6]);
      if (!flags || !metric || !(*flags & 1))
        continue;
      if (*metric < selected_metric) {
        selected = fields[0];
        selected_metric = *metric;
      }
    }
    return selected;
  }

  void EmitNetwork(std::ostream &output) const {
    const std::string selected = DefaultInterface();
    std::ifstream stream(Join(paths_.proc, "net/dev"));
    std::string line;
    std::getline(stream, line);
    std::getline(stream, line);
    while (std::getline(stream, line)) {
      const auto colon = line.find(':');
      if (colon == std::string::npos)
        continue;
      const std::string interface = Trim(line.substr(0, colon));
      if (interface.empty() || interface == "lo")
        continue;
      const auto fields = SplitWhitespace(line.substr(colon + 1));
      if (fields.size() < 16)
        continue;
      const std::string net_path =
          Join(Join(paths_.sys, "class/net"), interface);
      const std::string state =
          ReadLine(Join(net_path, "operstate")).value_or("unknown");
      const bool physical = Exists(Join(net_path, "device/uevent"));
      output << "network\t" << interface << '\t' << fields[0] << '\t'
             << fields[8] << '\t' << Sanitize(state) << '\t'
             << (interface == selected ? 1 : 0) << '\t' << (physical ? 1 : 0)
             << '\n';
    }
  }

  void EmitDisks(std::ostream &output) const {
    for (const auto &device : block_devices_) {
      const auto dev = ReadLine(Join(device.path, "dev"));
      const auto stat = ReadLine(Join(device.path, "stat"));
      if (!stat)
        continue;
      const auto fields = SplitWhitespace(*stat);
      if (fields.size() < 7)
        continue;
      output << "disk\t" << (dev ? *dev : "") << '\t' << device.name << '\t'
             << fields[2] << '\t' << fields[6] << '\n';
    }
  }

  void EmitCpuFrequency(std::ostream &output) const {
    double total = 0;
    std::size_t count = 0;
    for (const auto &path : cpu_frequency_paths_) {
      const auto value = ReadUnsigned(path);
      if (!value)
        continue;
      total += static_cast<double>(*value) / 1000.0;
      ++count;
    }
    if (count == 0) {
      std::ifstream stream(Join(paths_.proc, "cpuinfo"));
      std::string line;
      while (std::getline(stream, line)) {
        if (!StartsWith(line, "cpu MHz"))
          continue;
        const auto colon = line.find(':');
        if (colon == std::string::npos)
          continue;
        const auto value = ParseDouble(Trim(line.substr(colon + 1)));
        if (value) {
          total += *value;
          ++count;
        }
      }
    }
    if (count > 0)
      output << "frequency\tcpu\t"
             << std::llround(total / static_cast<double>(count)) << "\tMHz\n";
  }
};

class ProcessCollector {
public:
  explicit ProcessCollector(Paths paths)
      : paths_(std::move(paths)),
        clock_ticks_(PositiveEnv("OMARCHY_SYSTEM_STATS_CLOCK_TICKS",
                                 SystemValue(_SC_CLK_TCK, 100))),
        page_kib_(std::max<std::uint64_t>(
            1, PositiveEnv("OMARCHY_SYSTEM_STATS_PAGE_SIZE",
                           SystemValue(_SC_PAGESIZE, 4096)) /
                   1024)) {}

  void Collect(std::ostream &output) {
    LoadUsers();
    ++generation_;
    output << "schema\tactivity-processes\t1\n";
    output << "sample\t" << UptimeSample(paths_) << '\t' << clock_ticks_ << '\t'
           << SystemBusyTicks() << '\n';

    for (const auto &name : DirectoryNames(paths_.proc)) {
      if (!IsDigits(name))
        continue;
      const auto parsed_pid = ParseUnsigned(name);
      if (!parsed_pid || *parsed_pid == static_cast<std::uint64_t>(getpid()))
        continue;
      EmitProcess(static_cast<pid_t>(*parsed_pid), Join(paths_.proc, name),
                  output);
    }

    for (auto iterator = cache_.begin(); iterator != cache_.end();) {
      if (iterator->second.generation != generation_)
        iterator = cache_.erase(iterator);
      else
        ++iterator;
    }
  }

private:
  struct Metadata {
    std::uint64_t start_ticks = 0;
    std::string user;
    std::uint64_t generation = 0;
  };

  Paths paths_;
  std::uint64_t clock_ticks_;
  std::uint64_t page_kib_;
  bool users_loaded_ = false;
  std::unordered_map<uid_t, std::string> users_;
  std::unordered_map<pid_t, Metadata> cache_;
  std::uint64_t generation_ = 0;

  void LoadUsers() {
    if (users_loaded_)
      return;
    users_loaded_ = true;
    std::ifstream stream(paths_.passwd);
    std::string line;
    while (std::getline(stream, line)) {
      std::vector<std::string> fields;
      std::size_t begin = 0;
      while (begin <= line.size()) {
        const auto colon = line.find(':', begin);
        fields.push_back(line.substr(begin, colon == std::string::npos
                                                ? std::string::npos
                                                : colon - begin));
        if (colon == std::string::npos)
          break;
        begin = colon + 1;
      }
      if (fields.size() < 3)
        continue;
      const auto uid = ParseUnsigned(fields[2]);
      if (uid)
        users_[static_cast<uid_t>(*uid)] = Sanitize(fields[0]);
    }
  }

  std::uint64_t SystemBusyTicks() const {
    const auto line = ReadLine(Join(paths_.proc, "stat"));
    if (!line)
      return 0;
    const auto fields = SplitWhitespace(*line);
    if (fields.size() < 9 || fields[0] != "cpu")
      return 0;
    std::uint64_t total = 0;
    for (const std::size_t index : {1U, 2U, 3U, 6U, 7U, 8U})
      total += ParseUnsigned(fields[index]).value_or(0);
    return total;
  }

  std::string ResolveUser(uid_t uid) const {
    const auto found = users_.find(uid);
    return found == users_.end() ? std::to_string(uid) : found->second;
  }

  static std::optional<uid_t> ProcessUid(const std::string &path) {
    std::ifstream stream(Join(path, "status"));
    std::string line;
    while (std::getline(stream, line)) {
      if (!StartsWith(line, "Uid:"))
        continue;
      const auto fields = SplitWhitespace(line);
      const auto uid =
          fields.size() > 1 ? ParseUnsigned(fields[1]) : std::nullopt;
      if (uid && *uid <= std::numeric_limits<uid_t>::max())
        return static_cast<uid_t>(*uid);
      return std::nullopt;
    }
    return std::nullopt;
  }

  void EmitProcess(pid_t pid, const std::string &path, std::ostream &output) {
    const auto raw_value = ReadText(Join(path, "stat"));
    if (!raw_value)
      return;
    const std::string &raw = *raw_value;
    const auto command_start = raw.find('(');
    const auto command_end = raw.rfind(") ");
    if (command_start == std::string::npos ||
        command_end == std::string::npos || command_start == 0 ||
        command_end <= command_start)
      return;

    const auto parsed_pid = ParseUnsigned(Trim(raw.substr(0, command_start)));
    if (!parsed_pid || *parsed_pid != static_cast<std::uint64_t>(pid))
      return;
    const auto fields = SplitWhitespace(raw.substr(command_end + 2));
    if (fields.size() < 22)
      return;

    const auto flags = ParseUnsigned(fields[6]);
    const auto user_ticks = ParseUnsigned(fields[11]);
    const auto system_ticks = ParseUnsigned(fields[12]);
    const auto start_ticks = ParseUnsigned(fields[19]);
    const auto resident_pages = ParseUnsigned(fields[21]);
    if (!flags || !user_ticks || !system_ticks || !start_ticks ||
        !resident_pages || (*flags & kKernelThreadFlag) || *start_ticks == 0 ||
        fields[0].size() != 1)
      return;

    auto &metadata = cache_[pid];
    if (metadata.start_ticks != *start_ticks) {
      const auto uid = ProcessUid(path);
      if (!uid)
        return;
      metadata.start_ticks = *start_ticks;
      metadata.user = ResolveUser(*uid);
    }
    metadata.generation = generation_;

    output << "process\t" << pid << '\t' << metadata.user << '\t' << fields[0]
           << '\t' << *start_ticks << '\t' << *user_ticks + *system_ticks
           << '\t' << *resident_pages * page_kib_ << '\t'
           << Sanitize(raw.substr(command_start + 1,
                                  command_end - command_start - 1))
           << '\n';
  }
};

std::string PciDeviceName(const std::string &vendor_hex,
                          const std::string &device_hex);

class ThermalCollector {
public:
  explicit ThermalCollector(Paths paths) : paths_(std::move(paths)) {}

  void Collect(std::ostream &output) {
    output << "schema\tactivity-thermals\t1\n";
    output << "sample\t" << UptimeSample(paths_) << '\n';
    auto value = CachedValue();
    if (!value) {
      Invalidate();
      Discover();
      value = CachedValue();
    }
    if (cached_path_.empty() || !value)
      return;
    output << "temperature\t" << cached_id_ << '\t' << Sanitize(cached_chip_)
           << '\t' << Sanitize(cached_label_) << '\t' << *value << '\n';
  }

  void CollectSensors(std::ostream &output) {
    output << "schema\tactivity-sensors\t1\n";
    output << "sample\t" << UptimeSample(paths_) << '\n';
    if (Clock::now() >= next_sensor_discovery_) {
      sensors_.clear();
      std::string cpu_model;
      std::ifstream cpuinfo(Join(paths_.proc, "cpuinfo"));
      std::string line;
      while (std::getline(cpuinfo, line)) {
        if (StartsWith(line, "model name")) {
          const auto colon = line.find(':');
          if (colon != std::string::npos) cpu_model = Trim(line.substr(colon + 1));
          break;
        }
      }
      const std::string root = Join(paths_.sys, "class/hwmon");
      for (const auto &hwmon : DirectoryNames(root)) {
        const std::string path = Join(root, hwmon);
        const std::string chip = ReadLine(Join(path, "name")).value_or(hwmon);
        const auto power_path = Join(path, "device/power/runtime_status");
        const auto power = ReadLine(power_path);
        if ((chip == "nvidia" && power.value_or("") != "active") ||
            (power && *power != "active" && *power != "unsupported")) continue;
        std::string category = "unknown", owner;
        const auto device = RealPath(Join(path, "device"));
        const auto location = BaseName(device.empty() ? RealPath(path) : device);
        if (chip == "k10temp" || chip == "coretemp" || chip == "zenpower") {
          category = "cpu";
          owner = cpu_model;
        } else if (chip == "amdgpu" || chip == "nouveau" || chip == "nvidia" || chip == "i915" || chip == "xe") {
          category = "gpu";
          auto vendor = Lowercase(ReadLine(Join(path, "device/vendor")).value_or(""));
          auto product = Lowercase(ReadLine(Join(path, "device/device")).value_or(""));
          if (StartsWith(vendor, "0x")) vendor.erase(0, 2);
          if (StartsWith(product, "0x")) product.erase(0, 2);
          owner = PciDeviceName(vendor, product);
        } else if (chip == "nvme" || chip == "drivetemp") {
          category = "storage";
          owner = ReadLine(Join(path, "device/model")).value_or("");
        } else if (chip == "it8613") {
          category = "motherboard";
          owner = "ITE IT8613E";
        } else if (chip == "spd5118" || chip == "jc42") {
          category = "memory";
        } else if (StartsWith(chip, "iwlwifi")) {
          category = "wifi";
        } else if (StartsWith(chip, "r8169") || StartsWith(chip, "r8125")) {
          category = "ethernet";
        }
        for (const auto &name : DirectoryNames(path)) {
          const bool temperature = StartsWith(name, "temp");
          if ((!temperature && !StartsWith(name, "fan")) || !EndsWith(name, "_input"))
            continue;
          if (sensors_.size() >= 128) break;
          const auto sensor = name.substr(0, name.size() - 6);
          sensors_.push_back({Join(path, name), hwmon + "/" + sensor, chip,
            ReadLine(Join(path, sensor + "_label")).value_or(sensor),
            power_path, category, Sanitize(owner), Sanitize(location), temperature});
        }
      }
      next_sensor_discovery_ = Clock::now() + std::chrono::seconds(30);
    }
    for (const auto &sensor : sensors_) {
      const auto power = ReadLine(sensor.power_path);
      if ((sensor.chip == "nvidia" && power.value_or("") != "active") ||
          (power && *power != "active" && *power != "unsupported")) continue;
      const auto raw = ReadLine(sensor.path);
      const auto value = raw ? ParseDouble(*raw) : std::nullopt;
      if (!value || !std::isfinite(*value) ||
          (sensor.temperature ? (*value < -40000 || *value >= 150000)
                              : (*value < 0 || *value > 100000))) continue;
      output << (sensor.temperature ? "temperature" : "fan") << '\t'
             << sensor.id << '\t' << Sanitize(sensor.chip) << '\t'
             << Sanitize(sensor.label) << '\t' << *value;
      if (!sensor.temperature) output << "\trpm";
      output << '\t' << sensor.category << '\t' << sensor.owner << '\t'
             << sensor.location << '\n';
    }
    const auto board = ReadLine(Join(paths_.sys, "class/dmi/id/board_name")).value_or("");
    if (board == "DRFXI") {
      for (const auto &hwmon : DirectoryNames(Join(paths_.sys, "class/hwmon"))) {
        const auto path = Join(Join(paths_.sys, "class/hwmon"), hwmon);
        if (ReadLine(Join(path, "name")).value_or("") != "it8613") continue;
        for (int channel = 2; channel <= 5; ++channel) {
          const auto name = "pwm" + std::to_string(channel);
          const auto duty = ReadUnsigned(Join(path, name));
          const auto mode = ReadUnsigned(Join(path, name + "_enable"));
          if (!duty || !mode) continue;
          output << "control\t" << name << '\t' << *duty << '\t' << *mode
                 << '\t' << ReadUnsigned(Join(path, "fan" + std::to_string(channel) + "_input")).value_or(0) << '\n';
        }
      }
    }
  }

private:
  struct Sensor {
    std::string path, id, chip, label, power_path, category, owner, location;
    bool temperature;
  };
  std::vector<Sensor> sensors_;
  Clock::time_point next_sensor_discovery_{};
  Paths paths_;
  std::string cached_path_;
  std::string cached_id_;
  std::string cached_chip_;
  std::string cached_label_;

  static int Rank(const std::string &chip, const std::string &label) {
    std::string chip_lower = chip;
    std::string label_lower = label;
    chip_lower = Lowercase(std::move(chip_lower));
    label_lower = Lowercase(std::move(label_lower));
    if (chip_lower == "coretemp" &&
        label_lower.find("package id") != std::string::npos)
      return 0;
    if (chip_lower == "k10temp" && label_lower == "tctl")
      return 1;
    if (label_lower.find("cpu") != std::string::npos ||
        label_lower.find("package") != std::string::npos ||
        label_lower == "tctl")
      return 2;
    if (chip_lower == "coretemp" || chip_lower == "k10temp")
      return 3;
    return 100;
  }

  std::optional<std::uint64_t> CachedValue() const {
    if (cached_path_.empty())
      return std::nullopt;
    const auto value = ReadUnsigned(cached_path_);
    if (value && *value > 0 && *value < 150000)
      return value;
    return std::nullopt;
  }

  void Invalidate() {
    cached_path_.clear();
    cached_id_.clear();
    cached_chip_.clear();
    cached_label_.clear();
  }

  void Discover() {
    const std::string root = Join(paths_.sys, "class/hwmon");
    int best_rank = 100;
    std::uint64_t best_value = 0;
    for (const auto &hwmon : DirectoryNames(root)) {
      if (!StartsWith(hwmon, "hwmon"))
        continue;
      const std::string hwmon_path = Join(root, hwmon);
      const std::string chip =
          ReadLine(Join(hwmon_path, "name")).value_or("unknown");
      for (const auto &name : DirectoryNames(hwmon_path)) {
        if (!StartsWith(name, "temp") || !EndsWith(name, "_input"))
          continue;
        const auto value = ReadUnsigned(Join(hwmon_path, name));
        if (!value || *value == 0 || *value >= 150000)
          continue;
        const std::string sensor = name.substr(0, name.size() - 6);
        const std::string label =
            ReadLine(Join(hwmon_path, sensor + "_label")).value_or(chip);
        const int rank = Rank(chip, label);
        if (rank >= 100 || rank > best_rank ||
            (rank == best_rank && *value <= best_value))
          continue;
        best_rank = rank;
        best_value = *value;
        cached_path_ = Join(hwmon_path, name);
        cached_id_ = hwmon + "/" + sensor;
        cached_chip_ = chip;
        cached_label_ = label;
      }
    }
  }
};

#include "DiagnosticJournal.h"

class StorageCollector {
public:
  explicit StorageCollector(Paths paths) : paths_(std::move(paths)) {}

  void Collect(std::ostream &output) const {
    output << "schema\tactivity-storage\t1\n";
    output << "sample\t" << UptimeSample(paths_) << '\n';

    auto volumes = !paths_.statfs_fixture.empty()
                       ? VolumesFromFixture(paths_.statfs_fixture)
                       : VolumesFromMounts();
    std::sort(volumes.begin(), volumes.end(),
              [](const Volume &left, const Volume &right) {
                if (left.path == "/")
                  return right.path != "/";
                if (right.path == "/")
                  return false;
                return left.path < right.path;
              });

    for (const auto &volume : volumes)
      output << "storage\t" << Sanitize(volume.path) << '\t' << volume.total
             << '\t' << volume.used << '\t' << volume.available << '\n';
  }

private:
  struct Volume {
    std::string path;
    std::string source;
    std::uint64_t total = 0;
    std::uint64_t used = 0;
    std::uint64_t available = 0;
    unsigned long fsid = 0;
  };

  Paths paths_;

  static bool FillVolume(Volume *volume, std::uint64_t block_size,
                         std::uint64_t blocks, std::uint64_t free_blocks,
                         std::uint64_t available_blocks) {
    if (!volume || block_size == 0 || blocks == 0)
      return false;
    free_blocks = std::min(free_blocks, blocks);
    available_blocks = std::min(available_blocks, blocks);
    volume->total = block_size * blocks;
    volume->used = block_size * (blocks - free_blocks);
    volume->available = block_size * available_blocks;
    return true;
  }

  static bool FillFromStatvfs(const std::string &path, Volume *volume) {
    struct statvfs values{};
    if (statvfs(path.c_str(), &values) != 0)
      return false;
    const std::uint64_t block_size =
        values.f_frsize ? values.f_frsize : values.f_bsize;
    if (!FillVolume(volume, block_size, values.f_blocks, values.f_bfree,
                    values.f_bavail))
      return false;
    volume->fsid = values.f_fsid;
    return true;
  }

  static std::vector<Volume> VolumesFromFixture(const std::string &path) {
    std::ifstream stream(path);
    std::vector<Volume> volumes;
    std::string line;
    while (std::getline(stream, line)) {
      const auto fields = SplitWhitespace(line);
      Volume volume;
      std::size_t offset = 0;
      if (fields.size() >= 5) {
        volume.path = fields[0];
        offset = 1;
      } else if (fields.size() >= 4) {
        volume.path = "/";
      } else {
        continue;
      }
      if (!FillVolume(&volume, ParseUnsigned(fields[offset]).value_or(0),
                      ParseUnsigned(fields[offset + 1]).value_or(0),
                      ParseUnsigned(fields[offset + 2]).value_or(0),
                      ParseUnsigned(fields[offset + 3]).value_or(0)))
        continue;
      if (volume.path.empty())
        volume.path = "/";
      volumes.push_back(std::move(volume));
    }
    return volumes;
  }

  static bool IsLocalFsType(std::string_view fstype) {
    return fstype == "ext2" || fstype == "ext3" || fstype == "ext4" ||
           fstype == "xfs" || fstype == "btrfs" || fstype == "f2fs" ||
           fstype == "bcachefs" || fstype == "zfs" || fstype == "zfs3" ||
           fstype == "nilfs2" || fstype == "jfs" || fstype == "reiserfs" ||
           fstype == "reiser4" || fstype == "vfat" || fstype == "msdos" ||
           fstype == "exfat" || fstype == "ntfs" || fstype == "ntfs3" ||
           fstype == "fuseblk" || fstype == "ufs" || fstype == "erofs";
  }

  static bool IsSkippedMountpoint(std::string_view path) {
    if (path == "/boot" || path == "/boot/efi" || path == "/boot/EFI" ||
        path == "/efi")
      return true;
    if (path == "/snap" || StartsWith(path, "/snap/"))
      return true;
    if (path == "/run" ||
        (StartsWith(path, "/run/") && !StartsWith(path, "/run/media/")))
      return true;
    return StartsWith(path, "/proc") || StartsWith(path, "/sys") ||
           StartsWith(path, "/dev");
  }

  static bool HasBindOption(const char *options) {
    if (!options || !*options)
      return false;
    std::string_view view(options);
    std::size_t start = 0;
    while (start <= view.size()) {
      const auto comma = view.find(',', start);
      const auto option = view.substr(
          start, comma == std::string_view::npos ? view.size() - start
                                                 : comma - start);
      if (option == "bind")
        return true;
      if (comma == std::string_view::npos)
        break;
      start = comma + 1;
    }
    return false;
  }

  static bool SameStoragePool(const Volume &left, const Volume &right) {
    if (left.fsid != 0 && left.fsid == right.fsid)
      return true;
    return !left.source.empty() && left.source == right.source;
  }

  std::vector<Volume> VolumesFromMounts() const {
    std::vector<Volume> volumes;
    Volume root;
    root.path = "/";
    if (FillFromStatvfs(paths_.root, &root))
      volumes.push_back(root);

    FILE *mounts = setmntent(Join(paths_.proc, "mounts").c_str(), "r");
    if (!mounts)
      return volumes;

    while (mntent *entry = getmntent(mounts)) {
      if (!entry->mnt_dir || !entry->mnt_type)
        continue;
      const std::string path = entry->mnt_dir;
      const std::string source = entry->mnt_fsname ? entry->mnt_fsname : "";
      if (path == "/") {
        if (!volumes.empty() && volumes[0].path == "/")
          volumes[0].source = source;
        continue;
      }
      if (path.empty() || !IsLocalFsType(entry->mnt_type) ||
          IsSkippedMountpoint(path) || HasBindOption(entry->mnt_opts))
        continue;
      Volume volume;
      volume.path = path;
      volume.source = source;
      if (!FillFromStatvfs(path, &volume))
        continue;
      bool duplicate = false;
      for (const auto &existing : volumes) {
        if (existing.path == volume.path || SameStoragePool(existing, volume)) {
          duplicate = true;
          break;
        }
      }
      if (!duplicate)
        volumes.push_back(std::move(volume));
    }
    endmntent(mounts);
    return volumes;
  }
};

std::string GpuVendor(std::string vendor) {
  vendor = Lowercase(std::move(vendor));
  if (vendor == "8086")
    return "Intel";
  if (vendor == "1002")
    return "AMD";
  if (vendor == "10de")
    return "NVIDIA";
  return "GPU";
}

std::string NormalizeHex(std::string value) {
  value = Trim(std::move(value));
  if (StartsWith(value, "0x"))
    value.erase(0, 2);
  return Lowercase(std::move(value));
}

std::optional<std::uint64_t> MaxFrequency(
    const std::vector<std::pair<std::string, std::uint64_t>> &patterns) {
  std::optional<std::uint64_t> best;
  for (const auto &[pattern, divisor] : patterns) {
    for (const auto &path : GlobPaths(pattern)) {
      const auto value = ReadUnsigned(path);
      if (!value || divisor == 0)
        continue;
      const std::uint64_t mhz = *value / divisor;
      if (!best || mhz > *best)
        best = mhz;
    }
  }
  return best;
}

struct FanReading {
  unsigned int index;
  unsigned int percent;
};

struct GpuAdapter {
  std::string id;
  std::string vendor_hex;
  std::string vendor;
  std::string driver;
  std::string name;
  std::string card_path;
  std::string device_path;
  double utilization = -1;
  std::int64_t memory_used = -1;
  std::int64_t memory_total = -1;
  std::string memory_kind = "unknown";
  double frequency_mhz = -1;
  double temperature = -1;
  std::vector<FanReading> fans;
};

struct GpuProcessReading {
  unsigned int pid;
  double utilization;
  unsigned long long timestamp;
};

struct NvidiaReading {
  std::string id;
  std::string name;
  double utilization = -1;
  std::int64_t memory_used = -1;
  std::int64_t memory_total = -1;
  double frequency_mhz = -1;
  double temperature = -1;
  std::vector<FanReading> fans;
  std::vector<GpuProcessReading> processes;
};

class NvidiaProvider {
public:
  explicit NvidiaProvider(std::string fixture) : fixture_(std::move(fixture)) {}

  ~NvidiaProvider() { Close(); }

  void Close() {
    if (initialized_ && shutdown_)
      shutdown_();
    initialized_ = false;
    attempted_ = false;
    if (library_)
      dlclose(library_);
    library_ = nullptr;
  }

  std::vector<NvidiaReading> Read(const std::vector<std::string> &active_ids,
                                  bool sensors = false) {
    if (!fixture_.empty())
      return ReadFixture();
    if (active_ids.empty()) return {};
    if (!Initialize())
      return {};

    std::vector<NvidiaReading> readings;
    for (const auto &id : active_ids) {
      void *device = nullptr;
      if (get_handle_(id.c_str(), &device) != 0 || !device)
        continue;
      NvidiaReading reading;
      reading.id = NormalizeBus(id);

      std::array<char, 128> name{};
      if (get_name_(device, name.data(), name.size()) == 0)
        reading.name = Sanitize(name.data());

      NvmlUtilization utilization{};
      if (get_utilization_(device, &utilization) == 0)
        reading.utilization = utilization.gpu;

      NvmlMemory memory{};
      if (get_memory_(device, &memory) == 0 && memory.total > 0) {
        reading.memory_used =
            static_cast<std::int64_t>(std::min(memory.used, memory.total));
        reading.memory_total = static_cast<std::int64_t>(memory.total);
      }

      unsigned int clock = 0;
      if (get_clock_(device, 0, &clock) == 0)
        reading.frequency_mhz = clock;
      if (sensors) {
        unsigned int temperature = 0;
        if (get_temperature_ && get_temperature_(device, 0, &temperature) == 0 && temperature < 150)
          reading.temperature = temperature;
        unsigned int count = 0;
        if (get_num_fans_ && get_fan_speed_v2_ && get_num_fans_(device, &count) == 0) {
          for (unsigned int fan = 0; fan < std::min(count, 8U); ++fan) {
            unsigned int speed = 0;
            if (get_fan_speed_v2_(device, fan, &speed) == 0 && speed <= 100)
              reading.fans.push_back({fan, speed});
          }
        } else if (get_fan_speed_) {
          unsigned int speed = 0;
          if (get_fan_speed_(device, &speed) == 0 && speed <= 100)
            reading.fans.push_back({0, speed});
        }
      }
      if (!sensors && get_process_utilization_) {
        const auto now = static_cast<unsigned long long>(
            std::chrono::duration_cast<std::chrono::microseconds>(
                std::chrono::system_clock::now().time_since_epoch()).count());
        std::vector<NvmlProcessSample> samples(8192);
        unsigned int count = samples.size();
        if (get_process_utilization_(device, samples.data(), &count, now - 5000000ULL) == 0
            && count <= samples.size()) {
          std::unordered_map<unsigned int, NvmlProcessSample> latest;
          for (unsigned int i = 0; i < count; ++i) {
            const auto &sample = samples[i];
            if (!sample.pid || sample.timestamp > now || now - sample.timestamp > 5000000ULL
                || sample.sm > 100 || sample.encoder > 100 || sample.decoder > 100) continue;
            const auto old = latest.find(sample.pid);
            if (old == latest.end() || old->second.timestamp < sample.timestamp)
              latest[sample.pid] = sample;
          }
          for (const auto &[pid, sample] : latest)
            reading.processes.push_back({pid, static_cast<double>(
                std::max({sample.sm, sample.encoder, sample.decoder})), sample.timestamp});
        }
      }
      if (!reading.id.empty())
        readings.push_back(std::move(reading));
    }
    Close();
    return readings;
  }

private:
  struct NvmlUtilization {
    unsigned int gpu;
    unsigned int memory;
  };

  struct NvmlProcessSample {
    unsigned int pid;
    unsigned long long timestamp;
    unsigned int sm;
    unsigned int memory;
    unsigned int encoder;
    unsigned int decoder;
  };

  struct NvmlMemory {
    unsigned long long total;
    unsigned long long free;
    unsigned long long used;
  };

  using Init = int (*)(unsigned int);
  using Shutdown = int (*)();
  using GetHandle = int (*)(const char *, void **);
  using GetName = int (*)(void *, char *, unsigned int);
  using GetUtilization = int (*)(void *, NvmlUtilization *);
  using GetMemory = int (*)(void *, NvmlMemory *);
  using GetProcessUtilization = int (*)(void *, NvmlProcessSample *, unsigned int *, unsigned long long);
  using GetClock = int (*)(void *, unsigned int, unsigned int *);
  using GetValue = int (*)(void *, unsigned int *);

  std::string fixture_;
  void *library_ = nullptr;
  bool attempted_ = false;
  bool initialized_ = false;
  Shutdown shutdown_ = nullptr;
  GetHandle get_handle_ = nullptr;
  GetName get_name_ = nullptr;
  GetUtilization get_utilization_ = nullptr;
  GetMemory get_memory_ = nullptr;
  GetProcessUtilization get_process_utilization_ = nullptr;
  GetClock get_clock_ = nullptr;
  GetClock get_temperature_ = nullptr;
  GetClock get_fan_speed_v2_ = nullptr;
  GetValue get_num_fans_ = nullptr;
  GetValue get_fan_speed_ = nullptr;

  template <typename Function> Function Symbol(const char *name) {
    return reinterpret_cast<Function>(dlsym(library_, name));
  }

  bool Initialize() {
    if (attempted_)
      return initialized_;
    attempted_ = true;
    library_ = dlopen("libnvidia-ml.so.1", RTLD_NOW | RTLD_LOCAL);
    if (!library_)
      return false;

    const auto init = Symbol<Init>("nvmlInitWithFlags");
    shutdown_ = Symbol<Shutdown>("nvmlShutdown");
    get_handle_ = Symbol<GetHandle>("nvmlDeviceGetHandleByPciBusId_v2");
    get_name_ = Symbol<GetName>("nvmlDeviceGetName");
    get_utilization_ = Symbol<GetUtilization>("nvmlDeviceGetUtilizationRates");
    get_memory_ = Symbol<GetMemory>("nvmlDeviceGetMemoryInfo");
    get_process_utilization_ = Symbol<GetProcessUtilization>("nvmlDeviceGetProcessUtilization");
    get_clock_ = Symbol<GetClock>("nvmlDeviceGetClockInfo");
    get_temperature_ = Symbol<GetClock>("nvmlDeviceGetTemperature");
    get_fan_speed_v2_ = Symbol<GetClock>("nvmlDeviceGetFanSpeed_v2");
    get_num_fans_ = Symbol<GetValue>("nvmlDeviceGetNumFans");
    get_fan_speed_ = Symbol<GetValue>("nvmlDeviceGetFanSpeed");
    if (!init || !shutdown_ || !get_handle_ ||
        !get_name_ || !get_utilization_ || !get_memory_ || !get_clock_) {
      Close();
      return false;
    }
    // NO_ATTACH can hide active GPUs from PCI-bus handle lookup.
    initialized_ = init(0U) == 0;
    if (!initialized_) Close();
    return initialized_;
  }

  static std::string NormalizeBus(std::string bus) {
    bus = Trim(std::move(bus));
    bus = Lowercase(std::move(bus));
    const auto first_colon = bus.find(':');
    if (first_colon == 8 && bus.size() >= 12)
      bus.erase(0, 4);
    return bus;
  }

  std::vector<NvidiaReading> ReadFixture() const {
    std::vector<NvidiaReading> readings;
    std::ifstream stream(fixture_);
    std::string line;
    while (std::getline(stream, line)) {
      std::vector<std::string> fields;
      std::size_t begin = 0;
      while (begin <= line.size()) {
        const auto tab = line.find('\t', begin);
        fields.push_back(line.substr(
            begin, tab == std::string::npos ? std::string::npos : tab - begin));
        if (tab == std::string::npos)
          break;
        begin = tab + 1;
      }
      if (fields.size() < 6)
        continue;
      NvidiaReading reading;
      reading.id = NormalizeBus(fields[0]);
      reading.name = Sanitize(fields[1]);
      reading.utilization = ParseDouble(fields[2]).value_or(-1);
      reading.memory_used =
          static_cast<std::int64_t>(ParseUnsigned(fields[3]).value_or(0));
      reading.memory_total =
          static_cast<std::int64_t>(ParseUnsigned(fields[4]).value_or(0));
      reading.frequency_mhz = ParseDouble(fields[5]).value_or(-1);
      if (!reading.id.empty())
        readings.push_back(std::move(reading));
    }
    return readings;
  }
};

std::string PciDeviceName(const std::string &vendor_hex,
                          const std::string &device_hex) {
  std::ifstream stream("/usr/share/hwdata/pci.ids");
  std::string line;
  bool in_vendor = false;
  std::string vendor_name;
  while (std::getline(stream, line)) {
    if (line.empty() || line[0] == '#')
      continue;
    if (line[0] != '\t') {
      if (line.size() < 6 || line[4] != ' ' || line[5] != ' ') {
        in_vendor = false;
        continue;
      }
      std::string id = line.substr(0, 4);
      id = Lowercase(std::move(id));
      in_vendor = id == vendor_hex;
      vendor_name = in_vendor ? Trim(line.substr(6)) : "";
      continue;
    }
    if (!in_vendor || line.size() < 7 || line[1] == '\t')
      continue;
    std::string id = line.substr(1, 4);
    id = Lowercase(std::move(id));
    if (id == device_hex)
      return Sanitize(vendor_name + " " + Trim(line.substr(7)));
  }
  return "";
}

double ActiveDpmClock(const std::string &path) {
  std::ifstream stream(path);
  std::string line;
  while (std::getline(stream, line)) {
    if (line.find('*') == std::string::npos)
      continue;
    std::string lower = line;
    lower = Lowercase(std::move(lower));
    const auto mhz = lower.find("mhz");
    if (mhz == std::string::npos)
      continue;
    std::size_t begin = mhz;
    while (begin > 0 &&
           (std::isdigit(static_cast<unsigned char>(lower[begin - 1])) ||
            lower[begin - 1] == '.'))
      --begin;
    return ParseDouble(lower.substr(begin, mhz - begin)).value_or(-1);
  }
  return -1;
}

class GpuCollector {
public:
  explicit GpuCollector(Paths paths)
      : paths_(std::move(paths)), nvidia_(paths_.nvidia_fixture),
        discovery_interval_(std::chrono::milliseconds(PositiveEnv(
            "OMARCHY_SYSTEM_STATS_GPU_DISCOVERY_INTERVAL_MS", 10000))) {}

  void Collect(std::ostream &output, bool sensors = false) {
    DiscoverAdapters();
    if (!sensors) RefreshDynamicValues();
    ApplyNvidia(sensors);
    if (sensors) {
      for (const auto &gpu : adapters_) {
        if (gpu.vendor_hex != "10de") continue;
        if (gpu.temperature >= 0)
          output << "temperature\tnvidia/" << gpu.id << "\tNVIDIA\t"
                 << Sanitize(gpu.name) << '\t' << gpu.temperature * 1000
                 << "\tgpu\t" << Sanitize(gpu.name) << '\t' << gpu.id << '\n';
        for (const auto &fan : gpu.fans)
          output << "fan\tnvidia/" << gpu.id << "/fan" << fan.index
                 << "\t" << Sanitize(gpu.name) << "\tfan" << fan.index + 1
                 << '\t' << fan.percent << "\tpercent\tgpu\t"
                 << Sanitize(gpu.name) << '\t' << gpu.id << '\n';
      }
      return;
    }

    output << "schema\tactivity-gpus\t1\n";
    output << "sample\t" << UptimeSample(paths_) << '\n';
    for (const auto &gpu : adapters_) {
      output << "gpu\t" << gpu.id << '\t' << gpu.vendor << '\t' << gpu.driver
             << '\t' << Sanitize(gpu.name) << '\t';
      EmitNumber(output, gpu.utilization);
      output << '\t' << gpu.memory_used << '\t' << gpu.memory_total << '\t'
             << gpu.memory_kind << '\t';
      EmitNumber(output, gpu.frequency_mhz);
      output << '\n';
    }
    for (const auto &[gpu, process] : nvidia_processes_) {
      const auto start = ProcessStart(process.pid);
      if (!start) continue;
      const auto now = std::chrono::duration<double>(
          std::chrono::system_clock::now().time_since_epoch()).count();
      const auto uptime = ParseDouble(UptimeSample(paths_)).value_or(0);
      const auto ticks = SystemValue(_SC_CLK_TCK, 100);
      if (uptime <= 0 || process.timestamp / 1000000.0 < now - uptime + *start / static_cast<double>(ticks)) continue;
      output << "process-gpu\t" << gpu << '\t' << process.pid << '\t' << *start
             << '\t' << process.utilization << '\n';
    }
    EmitDrmClients(output);
  }

private:
  struct EngineValue {
    double busy = 0;
    double total = -1;
    double capacity = 1;
    std::string kind;
  };

  struct ClientSample {
    std::string client;
    std::string pdev;
    std::unordered_map<std::string, double> resident;
    std::unordered_map<std::string, EngineValue> engines;
  };

  struct EngineRow {
    std::string pdev;
    std::string client;
    std::string name;
    EngineValue value;
  };

  Paths paths_;
  NvidiaProvider nvidia_;
  bool adapters_discovered_ = false;
  Clock::time_point next_adapter_discovery_{};
  bool nvidia_present_ = false;
  std::vector<GpuAdapter> adapters_;
  std::vector<std::string> fdinfo_paths_;
  std::vector<std::pair<std::string, GpuProcessReading>> nvidia_processes_;

  std::optional<std::uint64_t> ProcessStart(unsigned int pid) const {
    const auto raw = ReadText(Join(Join(paths_.proc, std::to_string(pid)), "stat"));
    if (!raw) return std::nullopt;
    const auto end = raw->rfind(") ");
    if (end == std::string::npos) return std::nullopt;
    const auto fields = SplitWhitespace(raw->substr(end + 2));
    return fields.size() > 19 ? ParseUnsigned(fields[19]) : std::nullopt;
  }
  Clock::time_point next_fd_discovery_{};
  std::chrono::milliseconds discovery_interval_;

  static void EmitNumber(std::ostream &output, double value) {
    if (!std::isfinite(value) || value < 0) {
      output << -1;
    } else if (std::fabs(value - std::round(value)) < 0.0001) {
      output << static_cast<long long>(std::llround(value));
    } else {
      output << std::fixed << std::setprecision(2) << value;
      output.unsetf(std::ios::floatfield);
    }
  }

  void DiscoverAdapters() {
    if (adapters_discovered_ && Clock::now() < next_adapter_discovery_)
      return;
    adapters_discovered_ = true;
    next_adapter_discovery_ = Clock::now() + std::chrono::seconds(30);
    adapters_.clear();
    nvidia_present_ = false;
    const std::string drm_root = Join(paths_.sys, "class/drm");
    std::unordered_set<std::string> seen;
    for (const auto &name : DirectoryNames(drm_root)) {
      if (!StartsWith(name, "card") ||
          !IsDigits(std::string_view(name).substr(4)))
        continue;
      const std::string card_path = Join(drm_root, name);
      const std::string device_path = Join(card_path, "device");
      if (!Exists(device_path))
        continue;
      const std::string real_device = RealPath(device_path);
      std::string id =
          BaseName(real_device.empty() ? device_path : real_device);
      if (id.find(':') == std::string::npos)
        id = name;
      id = Lowercase(std::move(id));
      if (!seen.insert(id).second)
        continue;

      GpuAdapter gpu;
      gpu.id = id;
      gpu.card_path = card_path;
      gpu.device_path = device_path;
      gpu.vendor_hex =
          NormalizeHex(ReadLine(Join(device_path, "vendor")).value_or(""));
      if (gpu.vendor_hex == "10de")
        nvidia_present_ = true;
      gpu.vendor = GpuVendor(gpu.vendor_hex);
      const std::string driver_path = RealPath(Join(device_path, "driver"));
      gpu.driver = driver_path.empty() ? "unknown" : BaseName(driver_path);
      gpu.name = ReadLine(Join(device_path, "product_name")).value_or("");
      if (gpu.name.empty()) {
        const std::string device_hex =
            NormalizeHex(ReadLine(Join(device_path, "device")).value_or(""));
        gpu.name = PciDeviceName(gpu.vendor_hex, device_hex);
      }
      if (gpu.name.empty())
        gpu.name = gpu.vendor + " GPU";
      adapters_.push_back(std::move(gpu));
    }
    if (!nvidia_present_)
      nvidia_present_ =
          !DirectoryNames(Join(paths_.proc, "driver/nvidia/gpus")).empty();
  }

  void RefreshDynamicValues() {
    for (auto &gpu : adapters_) {
      gpu.utilization = -1;
      gpu.memory_used = -1;
      gpu.memory_total = -1;
      gpu.memory_kind = "unknown";
      gpu.frequency_mhz = -1;

      // Do not reset an autosuspend timer by reading telemetry on a sleeping dGPU.
      const auto power = ReadLine(Join(gpu.device_path, "power/runtime_status"));
      if (power && *power != "active" && *power != "unsupported") continue;
      if (gpu.vendor_hex == "10de") continue;

      if (gpu.vendor_hex == "1002") {
        const auto busy = ReadLine(Join(gpu.device_path, "gpu_busy_percent"));
        if (busy)
          gpu.utilization = ParseDouble(*busy).value_or(-1);
        auto used = ReadUnsigned(Join(gpu.device_path, "mem_info_vram_used"));
        auto total = ReadUnsigned(Join(gpu.device_path, "mem_info_vram_total"));
        if (used && total && *total > 0) {
          gpu.memory_used = static_cast<std::int64_t>(std::min(*used, *total));
          gpu.memory_total = static_cast<std::int64_t>(*total);
          gpu.memory_kind = "vram";
        } else {
          used = ReadUnsigned(Join(gpu.device_path, "mem_info_gtt_used"));
          total = ReadUnsigned(Join(gpu.device_path, "mem_info_gtt_total"));
          if (used && total && *total > 0) {
            gpu.memory_used =
                static_cast<std::int64_t>(std::min(*used, *total));
            gpu.memory_kind = "shared";
          }
        }
      }

      if (gpu.vendor_hex == "8086") {
        auto frequency = MaxFrequency({
            {Join(gpu.device_path, "tile*/gt*/freq*/act_freq"), 1},
            {Join(gpu.card_path, "gt/gt*/rps_act_freq_mhz"), 1},
            {Join(gpu.card_path, "gt_act_freq_mhz"), 1},
        });
        if (!frequency) {
          frequency = MaxFrequency({
              {Join(gpu.device_path, "tile*/gt*/freq*/cur_freq"), 1},
              {Join(gpu.card_path, "gt/gt*/rps_cur_freq_mhz"), 1},
              {Join(gpu.card_path, "gt_cur_freq_mhz"), 1},
          });
        }
        if (frequency)
          gpu.frequency_mhz = *frequency;
      } else if (gpu.vendor_hex == "1002") {
        const auto frequency = MaxFrequency(
            {{Join(gpu.device_path, "hwmon/hwmon*/freq1_input"), 1000000}});
        if (frequency)
          gpu.frequency_mhz = *frequency;
        else
          gpu.frequency_mhz =
              ActiveDpmClock(Join(gpu.device_path, "pp_dpm_sclk"));
      }

      if (gpu.frequency_mhz < 0) {
        const auto frequency = MaxFrequency({
            {Join(gpu.device_path, "devfreq/*/cur_freq"), 1000000},
            {Join(gpu.device_path, "hwmon/hwmon*/freq1_input"), 1000000},
        });
        if (frequency)
          gpu.frequency_mhz = *frequency;
      }
    }
  }

  void ApplyNvidia(bool sensors) {
    nvidia_processes_.clear();
    for (auto &gpu : adapters_) { gpu.temperature = -1; gpu.fans.clear(); }
    if (!nvidia_present_ && paths_.nvidia_fixture.empty())
      return;
    std::vector<std::string> active_ids;
    for (const auto &gpu : adapters_) {
      if (gpu.vendor_hex == "10de" &&
          ReadLine(Join(gpu.device_path, "power/runtime_status")).value_or("") == "active")
        active_ids.push_back(gpu.id);
    }
    for (const auto &reading : nvidia_.Read(active_ids, sensors)) {
      auto found =
          std::find_if(adapters_.begin(), adapters_.end(),
                       [&](const auto &gpu) { return gpu.id == reading.id; });
      if (found == adapters_.end()) {
        GpuAdapter gpu;
        gpu.id = reading.id;
        gpu.vendor_hex = "10de";
        gpu.vendor = "NVIDIA";
        gpu.driver = "nvidia";
        gpu.name = reading.name.empty() ? "NVIDIA GPU" : reading.name;
        adapters_.push_back(std::move(gpu));
        found = std::prev(adapters_.end());
      }
      for (const auto &process : reading.processes)
        nvidia_processes_.emplace_back(reading.id, process);
      found->vendor = "NVIDIA";
      found->driver = "nvidia";
      if (!reading.name.empty())
        found->name = reading.name;
      found->utilization = reading.utilization;
      found->frequency_mhz = reading.frequency_mhz;
      found->temperature = reading.temperature;
      found->fans = reading.fans;
      if (reading.memory_total > 0) {
        found->memory_used =
            std::min(reading.memory_used, reading.memory_total);
        found->memory_total = reading.memory_total;
        found->memory_kind = "vram";
      }
    }
  }

  void DiscoverFdinfoPaths() {
    std::vector<std::string> discovered;
    for (const auto &pid : DirectoryNames(paths_.proc)) {
      if (!IsDigits(pid) || ParseUnsigned(pid).value_or(0) ==
                                static_cast<std::uint64_t>(getpid()))
        continue;
      const std::string fd_root = Join(Join(paths_.proc, pid), "fd");
      DIR *directory = opendir(fd_root.c_str());
      if (!directory)
        continue;
      while (dirent *entry = readdir(directory)) {
        const std::string fd(entry->d_name);
        if (!IsDigits(fd))
          continue;
        const std::string link_path = Join(fd_root, fd);
        std::array<char, PATH_MAX> target{};
        const ssize_t length =
            readlink(link_path.c_str(), target.data(), target.size() - 1);
        if (length <= 0)
          continue;
        target[static_cast<std::size_t>(length)] = '\0';
        if (!StartsWith(target.data(), "/dev/dri/"))
          continue;
        const std::string fdinfo =
            Join(Join(Join(paths_.proc, pid), "fdinfo"), fd);
        if (Exists(fdinfo))
          discovered.push_back(fdinfo);
      }
      closedir(directory);
    }
    std::sort(discovered.begin(), discovered.end());
    discovered.erase(std::unique(discovered.begin(), discovered.end()),
                     discovered.end());
    fdinfo_paths_ = std::move(discovered);
    next_fd_discovery_ = Clock::now() + discovery_interval_;
  }

  static double ByteValue(double amount, const std::string &unit) {
    if (unit == "KiB")
      return amount * 1024.0;
    if (unit == "MiB")
      return amount * 1024.0 * 1024.0;
    if (unit == "GiB")
      return amount * 1024.0 * 1024.0 * 1024.0;
    return amount;
  }

  static std::optional<ClientSample> ParseFdinfo(const std::string &path) {
    std::ifstream stream(path);
    if (!stream)
      return std::nullopt;
    ClientSample sample;
    std::unordered_map<std::string, double> busy;
    std::unordered_map<std::string, double> totals;
    std::unordered_map<std::string, double> capacities;
    std::unordered_map<std::string, std::string> kinds;
    std::string line;
    while (std::getline(stream, line)) {
      auto fields = SplitWhitespace(line);
      if (fields.empty())
        continue;
      std::string key = fields[0];
      if (!key.empty() && key.back() == ':')
        key.pop_back();
      if (key == "drm-client-id" && fields.size() > 1)
        sample.client = fields[1];
      else if (key == "drm-pdev" && fields.size() > 1) {
        sample.pdev = fields[1];
        sample.pdev = Lowercase(std::move(sample.pdev));
      } else if (StartsWith(key, "drm-resident-") && fields.size() > 1) {
        const std::string region = key.substr(std::strlen("drm-resident-"));
        const double amount = ParseDouble(fields[1]).value_or(0);
        sample.resident[region] =
            ByteValue(amount, fields.size() > 2 ? fields[2] : "");
      } else if (StartsWith(key, "drm-engine-capacity-") && fields.size() > 1) {
        capacities[key.substr(std::strlen("drm-engine-capacity-"))] =
            ParseDouble(fields[1]).value_or(1);
      } else if (StartsWith(key, "drm-total-cycles-") && fields.size() > 1) {
        totals[key.substr(std::strlen("drm-total-cycles-"))] =
            ParseDouble(fields[1]).value_or(-1);
      } else if (StartsWith(key, "drm-cycles-") && fields.size() > 1) {
        const std::string engine = key.substr(std::strlen("drm-cycles-"));
        busy[engine] = ParseDouble(fields[1]).value_or(0);
        kinds[engine] = "cycles";
      } else if (StartsWith(key, "drm-engine-") && fields.size() > 1) {
        const std::string engine = key.substr(std::strlen("drm-engine-"));
        busy[engine] = ByteValue(ParseDouble(fields[1]).value_or(0),
                                 fields.size() > 2 ? fields[2] : "");
        kinds[engine] = "time";
      }
    }
    if (sample.client.empty() || sample.pdev.empty())
      return std::nullopt;
    for (const auto &[name, value] : busy) {
      if (kinds[name] == "cycles" && !totals.count(name))
        continue;
      sample.engines[name] = {
          value,
          totals.count(name) ? totals[name] : -1,
          capacities.count(name) && capacities[name] > 0 ? capacities[name] : 1,
          kinds[name],
      };
    }
    return sample;
  }

  void EmitDrmClients(std::ostream &output) {
    if (adapters_.empty())
      return;
    if (Clock::now() >= next_fd_discovery_)
      DiscoverFdinfoPaths();

    std::unordered_set<std::string> known;
    for (const auto &gpu : adapters_)
      known.insert(gpu.id);
    std::unordered_set<std::string> clients;
    std::unordered_set<std::string> process_clients;
    std::unordered_map<std::string, double> dedicated;
    std::unordered_map<std::string, double> shared;
    std::vector<EngineRow> engines;
    std::vector<std::string> retained;

    for (const auto &path : fdinfo_paths_) {
      const auto sample = ParseFdinfo(path);
      if (!sample)
        continue;
      retained.push_back(path);
      if (!known.count(sample->pdev))
        continue;
      const std::string client_key = sample->pdev + "\t" + sample->client;
      const auto pid_name = BaseName(path.substr(0, path.rfind("/fdinfo/")));
      const auto pid = ParseUnsigned(pid_name);
      const auto start = pid ? ProcessStart(static_cast<unsigned int>(*pid)) : std::nullopt;
      if (start && process_clients.insert(pid_name + "\t" + client_key).second) {
        for (const auto &[name, value] : sample->engines)
          output << "process-engine\t" << sample->pdev << '\t' << sample->client << '\t'
                 << name << '\t' << std::llround(value.busy) << '\t'
                 << std::llround(value.total) << '\t' << std::llround(value.capacity)
                 << '\t' << value.kind << '\t' << *pid << '\t' << *start << '\n';
      }
      if (!clients.insert(client_key).second)
        continue;
      for (const auto &[region, bytes] : sample->resident) {
        if (region.find("vram") != std::string::npos ||
            region.find("local") != std::string::npos)
          dedicated[sample->pdev] += bytes;
        else
          shared[sample->pdev] += bytes;
      }
      for (const auto &[name, value] : sample->engines)
        engines.push_back({sample->pdev, sample->client, name, value});
    }
    fdinfo_paths_ = std::move(retained);

    for (const auto &engine : engines) {
      output << "engine\t" << engine.pdev << '\t' << engine.client << '\t'
             << engine.name << '\t' << std::llround(engine.value.busy) << '\t'
             << std::llround(engine.value.total) << '\t'
             << std::llround(engine.value.capacity) << '\t' << engine.value.kind
             << '\n';
    }
    for (const auto &[id, bytes] : dedicated)
      output << "gpu-memory\t" << id << "\tvram\t" << std::llround(bytes)
             << '\n';
    for (const auto &[id, bytes] : shared)
      output << "gpu-memory\t" << id << "\tshared\t" << std::llround(bytes)
             << '\n';
  }
};

class Sampler {
public:
  explicit Sampler(Paths paths)
      : resources_(paths), processes_(paths), thermals_(paths), storage_(paths),
        gpus_(paths), journal_(paths), sensor_journal_(paths, "sensors") {}

  void Collect(const std::string &kind, std::ostream &destination) {
    FrameBuffer frame;
    std::ostream output(&frame);
    input_overflow = false;
    if (kind == "sensors-on" || kind == "sensors-off") {
      if (kind == "sensors-on") sensor_journal_.Enable();
      else sensor_journal_.Disable();
      output << "schema\tactivity-sensor-recording\t1\n"
             << "enabled\t" << (sensor_journal_.enabled ? 1 : 0) << '\n'
             << "error\t" << sensor_journal_.error << '\n';
    } else if (kind == "journal-on" || kind == "journal-off" || kind == "journal" || kind == "diagnostics") {
      if(kind=="journal-on") journal_.Enable();
      else if(kind=="journal-off") journal_.Disable();
      else if(kind=="journal") journal_.Sample();
      else if(journal_.enabled) journal_.Context();
      output << "schema\tactivity-journal\t1\n"
             << "enabled\t" << (journal_.enabled?1:0) << '\n'
             << "error\t" << journal_.error << '\n';
    } else if (kind == "resources")
      resources_.Collect(output);
    else if (kind == "glance")
      resources_.Glance(output);
    else if (kind == "processes")
      processes_.Collect(output);
    else if (kind == "thermals")
      thermals_.Collect(output);
    else if (kind == "sensors") {
      thermals_.CollectSensors(output);
      gpus_.Collect(output, true);
    } else if (kind == "gpus")
      gpus_.Collect(output);
    else if (kind == "storage")
      storage_.Collect(output);
    if (frame.exceeded || input_overflow) {
      journal_.Observe(kind,"error\tcapacity\n");
      destination << "error\tcapacity\n";
      return;
    }
    journal_.Observe(kind,frame.data);
    if (kind == "sensors") {
      sensor_journal_.SaveSensors(frame.data);
      if (!sensor_journal_.error.empty()) frame.data += "recording-error\t" + sensor_journal_.error + "\n";
    }
    destination << frame.data;
  }

  void BarWidget(std::ostream &output) { resources_.BarWidget(output); }

private:
  ResourceCollector resources_;
  ProcessCollector processes_;
  ThermalCollector thermals_;
  StorageCollector storage_;
  GpuCollector gpus_;
  DiagnosticJournal journal_;
  DiagnosticJournal sensor_journal_;
};

volatile sig_atomic_t reader_stopping = 0;
void StopReader(int) { reader_stopping = 1; }

void Reader(Sampler &sampler) {
  // A signal only changes admission; cleanup is performed by journal's owner.
  // poll/read avoids iostream restart semantics while waiting for the next line.
  struct sigaction action{};
  action.sa_handler=StopReader;sigemptyset(&action.sa_mask);
  sigaction(SIGTERM,&action,nullptr);
  std::string request;
  while (!reader_stopping) {
    pollfd input{STDIN_FILENO,POLLIN,0};
    const int ready=poll(&input,1,-1);
    if(ready<0 && errno==EINTR) continue;
    if(ready<=0) break;
    char ch=0;const auto n=read(STDIN_FILENO,&ch,1);
    if(n<=0) break;
    if(ch!='\n') { if(request.size()>=31) break;request+=ch;continue; }
    request=Trim(request);
    if (request != "glance" && request != "resources" && request != "processes" &&
        request != "thermals" && request != "sensors" && request != "sensors-on" && request != "sensors-off" && request != "gpus" && request != "storage" &&
        request != "journal-on" && request != "journal-off" && request != "journal" && request != "diagnostics") {
      request.clear();
      continue;
    }
    sampler.Collect(request, std::cout);
    std::cout << "snapshot-end\t" << request << '\n' << std::flush;
    request.clear();
  }
}

int Run(int argc, char **argv) {
  Sampler sampler(UserPaths());
  if (argc == 1)
    return 0;
  if (argc != 2)
    return 64;
  const std::string mode(argv[1]);
  if (mode == "--bar-widget")
    sampler.BarWidget(std::cout);
  else if (mode == "--activity-reader")
    Reader(sampler);
  else if (mode == "--activity-resources")
    sampler.Collect("resources", std::cout);
  else if (mode == "--activity-processes")
    sampler.Collect("processes", std::cout);
  else if (mode == "--activity-thermals")
    sampler.Collect("thermals", std::cout);
  else if (mode == "--activity-sensors")
    sampler.Collect("sensors", std::cout);
  else if (mode == "--activity-gpus")
    sampler.Collect("gpus", std::cout);
  else if (mode == "--activity-storage")
    sampler.Collect("storage", std::cout);
  else if (mode == "--version")
    std::cout << "activity-sampler 2.6.0\n";
  else {
    std::cerr << "Usage: activity-sampler "
                 "[--bar-widget|--activity-reader|--activity-resources|"
                 "--activity-processes|--activity-thermals|--activity-sensors|--activity-gpus|"
                 "--activity-storage]\n";
    return 64;
  }
  return std::cout.good() ? 0 : 1;
}

} // namespace

int main(int argc, char **argv) {
  const auto parent = getppid();
  if (prctl(PR_SET_PDEATHSIG, SIGTERM) != 0 || getppid() != parent) return 1;
  std::ios::sync_with_stdio(false);
  std::cin.tie(nullptr);
  return Run(argc, argv);
}
