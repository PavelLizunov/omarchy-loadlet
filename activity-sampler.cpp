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
  pos_type seekoff(off_type offset, std::ios_base::seekdir direction,
                   std::ios_base::openmode mode) override {
    if (offset == 0 && direction == std::ios_base::cur && (mode & std::ios_base::out))
      return static_cast<off_type>(data.size());
    return pos_type(off_type(-1));
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

// Reject a record that extends past its own budget without overflowing the frame.
std::optional<std::string> ReadRecord(const std::string &path, std::size_t limit) {
  std::ifstream stream(path, std::ios::binary);
  if (!stream) return std::nullopt;
  std::string record(limit + 1, '\0');
  stream.read(record.data(), record.size());
  if (stream.bad() || !stream.eof()) return std::nullopt;
  record.resize(static_cast<std::size_t>(stream.gcount()));
  return record;
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

std::string PciBus(std::string bus) {
  bus = Lowercase(std::move(bus));
  if (bus.size() == 16 && StartsWith(bus, "0000")) bus.erase(0, 4);
  if (bus.size() != 12 || bus[4] != ':' || bus[7] != ':' || bus[10] != '.' ||
      bus[11] < '0' || bus[11] > '7') return "";
  for (std::size_t i : {0U, 1U, 2U, 3U, 5U, 6U, 8U, 9U}) {
    if (!std::isxdigit(static_cast<unsigned char>(bus[i]))) return "";
  }
  return bus;
}

std::string ChannelBus(std::string bus) {
  std::replace(bus.begin(), bus.end(), ':', '_');
  std::replace(bus.begin(), bus.end(), '.', '_');
  return bus;
}

std::string ChannelSlug(const std::string &value, const char *fallback) {
  std::string slug;
  for (unsigned char ch : Lowercase(value)) {
    if ((ch < 'a' || ch > 'z') && (ch < '0' || ch > '9') && ch != '-') ch = '_';
    if (ch == '_' && (slug.empty() || slug.back() == '_')) continue;
    slug += static_cast<char>(ch);
  }
  if (!slug.empty() && slug.back() == '_') slug.pop_back();
  return slug.empty() ? fallback : slug.substr(0, 32);
}

std::string DriverPath(const std::string &device) {
  return device.empty() ? "" : RealPath(Join(device, "driver"));
}

bool RuntimeReadable(const std::string &device, bool nvidia = false) {
  if (device.empty()) return !nvidia;
  const auto power = ReadLine(Join(device, "power/runtime_status"));
  return nvidia ? power == "active" : !power || *power == "active" || *power == "unsupported";
}

template<class T> std::string OptionalNumber(const std::optional<T> &value) {
  return value ? std::to_string(*value) : "";
}

struct FanChannel {
  std::string id, backend, driver, owner, label, location;
  std::optional<unsigned int> duty;
  std::string mode = "unknown";
  std::optional<std::uint64_t> rpm;
  unsigned int minimum = 0, maximum = 100;
  bool controllable = false;
  std::string legacy, sensor;

  void Emit(std::ostream &out) const {
    out << "fan-channel\t" << id << '\t' << backend << '\t' << Sanitize(driver) << '\t'
        << Sanitize(owner) << '\t' << Sanitize(label) << '\t' << Sanitize(location)
        << '\t' << OptionalNumber(duty) << '\t' << mode << '\t' << OptionalNumber(rpm)
        << '\t' << minimum << '\t' << maximum << '\t' << controllable << '\t' << legacy
        << '\t' << sensor << '\n';
  }
};

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
    const auto available = memory.count("MemAvailable") ? memory["MemAvailable"] : memory["MemFree"];
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
    output << "memory\t" << get("MemTotal") << '\t' << get(values.count("MemAvailable") ? "MemAvailable" : "MemFree")
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
    // proc stat is one bounded record; avoid a locale/stream allocation per PID.
    const int fd = open(Join(path, "stat").c_str(), O_RDONLY | O_CLOEXEC);
    if (fd < 0) return;
    std::array<char, 8192> buffer{};
    ssize_t size;
    do { size=read(fd,buffer.data(),buffer.size()); } while(size<0 && errno==EINTR);
    close(fd);
    if (size<=0) return;
    if (size==static_cast<ssize_t>(buffer.size())) { input_overflow=true; return; }
    const std::string raw(buffer.data(),static_cast<std::size_t>(size));
    const auto command_start = raw.find('(');
    const auto command_end = raw.rfind(") ");
    if (command_start == std::string::npos ||
        command_end == std::string::npos || command_start == 0 ||
        command_end <= command_start)
      return;

    const auto parsed_pid = ParseUnsigned(Trim(raw.substr(0, command_start)));
    if (!parsed_pid || *parsed_pid != static_cast<std::uint64_t>(pid))
      return;
    std::vector<std::string_view> fields;
    fields.reserve(24);
    std::size_t position=command_end+2;
    while(position<raw.size() && fields.size()<22) {
      while(position<raw.size() && std::isspace(static_cast<unsigned char>(raw[position])))++position;
      const auto begin=position;
      while(position<raw.size() && !std::isspace(static_cast<unsigned char>(raw[position])))++position;
      if(position>begin)fields.emplace_back(raw.data()+begin,position-begin);
    }
    if (fields.size() < 22) return;

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
    output << "schema\tactivity-thermals\t1\nsample\t" << UptimeSample(paths_) << '\n';
    auto value = CachedValue();
    if (!value && Clock::now() >= next_discovery_) {
      cached_.reset();
      Discover();
      value = CachedValue();
    }
    if (value)
      output << "temperature\t" << cached_->id << '\t' << Sanitize(cached_chip_.name)
             << '\t' << Sanitize(cached_->label) << '\t' << *value << '\n';
  }

  void CollectSensors(std::ostream &output, bool cpu_only = false, bool evidence = false) {
    output << "schema\tactivity-sensors\t1\nsample\t" << UptimeSample(paths_) << '\n';
    if (Clock::now() >= next_sensor_discovery_) DiscoverSensors();
    const auto board = cpu_only ? "" : ReadLine(Join(paths_.sys, "class/dmi/id/board_name")).value_or("");
    std::unordered_set<std::string> channels;
    for (const auto &chip : chips_) {
      if (cpu_only && chip.category != "cpu") continue;
      const bool current = chip.Current();
      if (!current) next_sensor_discovery_ = {};
      const bool readable = current && chip.Readable();
      std::unordered_set<std::string> emitted_fans;
      for (const auto &sensor : chip.sensors) {
        if (!output) return;
        if (!readable) {
          if (evidence) output << "sensor-missing\t" << sensor.id << '\t'
                               << (current ? "asleep_or_power_unknown" : "unavailable") << '\n';
          continue;
        }
        if (sensor.kind == "power" && (!evidence || cpu_only)) continue;
        if (evidence && !cpu_only)
          output << "sensor-source\t" << sensor.id << '\t' << Sanitize(chip.name) << '\t'
                 << Sanitize(chip.location) << '\t'
                 << ReadLine(Join(chip.path, "update_interval")).value_or("unknown") << '\n';
        errno = 0;
        const auto raw = ReadLine(Join(chip.path, sensor.file));
        const auto read_error = errno;
        if (!raw && evidence)
          output << "sensor-missing\t" << sensor.id << '\t'
                 << (read_error == EACCES || read_error == EPERM ? "permission_denied" : "unavailable") << '\n';
        const auto value = raw ? ParseDouble(*raw) : std::nullopt;
        if (!value || (sensor.kind == "temperature" ? (*value < -40000 || *value >= 150000)
                       : (*value < 0 || (sensor.kind == "fan" && *value > 100000)))) continue;
        output << sensor.kind << '\t' << sensor.id << '\t' << Sanitize(chip.name) << '\t'
               << Sanitize(sensor.label) << '\t' << *value;
        if (sensor.kind == "fan") {
          output << "\trpm";
          emitted_fans.insert(sensor.id);
        } else if (sensor.kind == "power") {
          output << "\tmicrowatt";
        }
        output << '\t' << chip.category << '\t' << Sanitize(chip.owner)
               << '\t' << Sanitize(chip.location) << '\n';
      }
      if (!cpu_only && readable) EmitChannels(output, chip, board, emitted_fans, channels);
    }
  }

private:
  struct Sensor {
    std::string file, id, label, kind;
  };
  struct Hwmon {
    std::string alias, path, device, driver, name, location, category, owner;
    dev_t filesystem = 0;
    ino_t inode = 0;
    std::vector<Sensor> sensors;
    std::vector<unsigned int> pwms;
    bool Current() const {
      struct stat status{};
      return RealPath(alias) == path && stat(path.c_str(), &status) == 0 &&
             status.st_dev == filesystem && status.st_ino == inode &&
             RealPath(Join(path, "device")) == device && DriverPath(device) == driver &&
             ReadLine(Join(path, "name")).value_or("") == name;
    }
    bool Readable() const {
      const bool nvidia = BaseName(driver) == "nvidia";
      return (Lowercase(name) != "nvidia" || nvidia) && RuntimeReadable(device, nvidia);
    }
  };

  std::vector<Hwmon> chips_;
  Clock::time_point next_sensor_discovery_{};
  Paths paths_;
  Hwmon cached_chip_;
  std::optional<Sensor> cached_;
  bool cached_zone_ = false;
  Clock::time_point next_discovery_{};

  static bool CpuChip(const std::string &chip) {
    return chip == "k10temp" || chip == "coretemp" || StartsWith(chip, "zenpower");
  }

  static bool MotherboardChip(const std::string &chip) {
    for (const auto *prefix : {"it87", "it86", "nct67", "nct6683", "nct6687", "f718", "w83627"}) {
      if (StartsWith(chip, prefix)) return true;
    }
    return false;
  }

  static std::string Category(const std::string &chip) {
    if (CpuChip(chip) || chip == "acpitz") return "cpu";
    if (chip == "amdgpu" || chip == "radeon" || chip == "nouveau" ||
        chip == "nvidia" || chip == "i915" || chip == "xe") return "gpu";
    if (chip == "nvme" || chip == "drivetemp") return "storage";
    if (chip == "spd5118" || chip == "jc42") return "memory";
    for (const auto *prefix : {"iwlwifi", "mt7921", "ath11k", "ath12k"}) {
      if (StartsWith(chip, prefix)) return "wifi";
    }
    for (const auto *prefix : {"r8169", "r8125", "igc", "igb", "e1000e"}) {
      if (StartsWith(chip, prefix)) return "ethernet";
    }
    if (chip == "battery" || StartsWith(chip, "bat") ||
        StartsWith(chip, "ucsi_source_psy") || chip == "corsairpsu") return "power";
    if (MotherboardChip(chip)) return "motherboard";
    for (const auto *prefix : {"asus-ec-sensors", "asus_wmi_sensors", "gigabyte_wmi", "msi-ec",
                              "thinkpad", "dell_smm", "hp-wmi", "acer-wmi", "asus-nb-wmi",
                              "apple-smc", "macsmc", "corsaircpro", "nzxt-kraken", "nzxt-smart2",
                              "aquacomputer_", "gigabyte_waterforce"}) {
      if (StartsWith(chip, prefix)) return "motherboard";
    }
    return "unknown";
  }

  Hwmon ResolveHwmon(const std::string &alias) const {
    Hwmon chip;
    chip.alias = alias;
    chip.path = RealPath(alias);
    struct stat status{};
    if (chip.path.empty() || stat(chip.path.c_str(), &status) != 0) {
      chip.path.clear();
      return chip;
    }
    chip.filesystem = status.st_dev;
    chip.inode = status.st_ino;
    chip.name = ReadLine(Join(chip.path, "name")).value_or("");
    chip.device = RealPath(Join(chip.path, "device"));
    chip.driver = DriverPath(chip.device);
    chip.location = BaseName(chip.device.empty() ? chip.path : chip.device);
    return chip;
  }

  void DiscoverSensors() {
    chips_.clear();
    const auto root = Join(paths_.sys, "class/hwmon");
    std::string cpu_model;
    std::ifstream cpuinfo(Join(paths_.proc, "cpuinfo"));
    std::string line;
    while (std::getline(cpuinfo, line)) {
      if (!StartsWith(line, "model name")) continue;
      const auto colon = line.find(':');
      if (colon != std::string::npos) cpu_model = Trim(line.substr(colon + 1));
      break;
    }
    std::size_t sensor_count = 0;
    for (const auto &entry : DirectoryNames(root)) {
      auto chip = ResolveHwmon(Join(root, entry));
      if (chip.path.empty()) continue;
      chip.category = Category(Lowercase(chip.name));
      if (chip.category == "cpu") chip.owner = cpu_model;
      if (chip.category == "gpu" && !chip.device.empty()) {
        auto vendor = Lowercase(ReadLine(Join(chip.device, "vendor")).value_or(""));
        auto product = Lowercase(ReadLine(Join(chip.device, "device")).value_or(""));
        if (StartsWith(vendor, "0x")) vendor.erase(0, 2);
        if (StartsWith(product, "0x")) product.erase(0, 2);
        chip.owner = PciDeviceName(vendor, product);
      }
      if (chip.category == "storage" && !chip.device.empty())
        chip.owner = ReadLine(Join(chip.device, "model")).value_or("");
      if (chip.name == "it8613") chip.owner = "ITE IT8613E";
      for (const auto &file : DirectoryNames(chip.path)) {
        if (StartsWith(file, "pwm") && IsDigits(std::string_view(file).substr(3))) {
          const auto number = ParseUnsigned(std::string_view(file).substr(3));
          if (number && *number >= 1 && *number <= 16 && file == "pwm" + std::to_string(*number))
            chip.pwms.push_back(static_cast<unsigned int>(*number));
        }
        if (sensor_count >= 128) continue;
        std::string kind;
        if (StartsWith(file, "temp") && EndsWith(file, "_input")) kind = "temperature";
        if (StartsWith(file, "fan") && EndsWith(file, "_input")) kind = "fan";
        if (chip.category == "gpu" && StartsWith(file, "power") &&
            (EndsWith(file, "_input") || EndsWith(file, "_average"))) kind = "power";
        if (kind.empty()) continue;
        const auto stem = file.substr(0, file.rfind('_'));
        const auto label = ReadLine(Join(chip.path, stem + "_label")).value_or(stem);
        const auto id = entry + "/" + (kind == "power" ? file : stem);
        chip.sensors.push_back({file, id, label, kind});
        ++sensor_count;
      }
      if (!chip.sensors.empty() || !chip.pwms.empty()) chips_.push_back(std::move(chip));
    }
    next_sensor_discovery_ = Clock::now() + std::chrono::seconds(30);
  }

  static bool WritableAttribute(const std::string &path) {
    struct stat status{};
    return stat(path.c_str(), &status) == 0 && S_ISREG(status.st_mode) && (status.st_mode & 0222);
  }

  static std::optional<unsigned int> PwmPercent(const std::optional<std::uint64_t> &pwm) {
    if (!pwm || *pwm > 255) return std::nullopt;
    return static_cast<unsigned int>((*pwm * 100 + 127) / 255);
  }

  static void EmitChannels(std::ostream &output, const Hwmon &chip, const std::string &board,
                           const std::unordered_set<std::string> &fans,
                           std::unordered_set<std::string> &emitted) {
    const auto bus = PciBus(BaseName(chip.device));
    const auto driver = Lowercase(chip.name);
    for (const auto number : chip.pwms) {
      if (!output) break;
      const auto index = std::to_string(number);
      const auto pwm = "pwm" + index;
      const auto path = Join(chip.path, pwm);
      const auto enable = path + "_enable";
      FanChannel row;
      row.driver = chip.name.empty() ? "unknown" : chip.name;
      row.owner = chip.owner;
      row.location = chip.location;
      if (board == "DRFXI" && driver == "it8613" && number >= 2 && number <= 5) {
        row.id = row.legacy = pwm;
        row.backend = "it8613";
      } else if (driver == "amdgpu" && !bus.empty() && number <= 8) {
        row.id = "amd." + ChannelBus(bus) + "." + pwm;
        row.backend = "amdgpu";
      } else {
        row.id = "hw." + ChannelSlug(driver, "unknown") + "." +
                 ChannelSlug(chip.location, "hwmon") + "." + pwm;
        row.backend = "hwmon";
      }
      if (!emitted.insert(row.id).second) continue;
      const auto fan = "fan" + index;
      const auto fan_id = BaseName(chip.alias) + "/" + fan;
      if (fans.count(fan_id)) row.sensor = fan_id;
      row.label = ReadLine(Join(chip.path, fan + "_label")).value_or(fan);
      if (Sanitize(row.label).empty()) row.label = fan;
      row.rpm = ReadUnsigned(Join(chip.path, fan + "_input"));
      const auto duty = ReadUnsigned(path);
      const auto mode = ReadUnsigned(enable);
      row.duty = PwmPercent(duty);
      if (mode) row.mode = *mode == 0 ? "full" : *mode == 1 ? "manual" : "auto";
      row.minimum = PwmPercent(ReadUnsigned(path + "_min")).value_or(0);
      row.maximum = PwmPercent(ReadUnsigned(path + "_max")).value_or(100);
      if (row.minimum > row.maximum) {
        row.minimum = 0;
        row.maximum = 100;
      }
      const bool known = row.backend != "hwmon" || MotherboardChip(driver);
      const bool read_only = driver == "asus-ec-sensors" || driver == "asus_wmi_sensors";
      row.controllable = !read_only && Exists(path) && Exists(enable) &&
                         (known || (WritableAttribute(path) && WritableAttribute(enable)));
      if (!row.legacy.empty() && duty && mode)
        output << "control\t" << pwm << '\t' << *duty << '\t' << *mode << '\t'
               << OptionalNumber(row.rpm) << '\n';
      row.Emit(output);
    }
  }

  static int Rank(const std::string &chip, const std::string &label) {
    const auto lower = Lowercase(label);
    if (chip == "coretemp" && StartsWith(lower, "package id")) return 0;
    if (lower == "tctl") return 1;
    if (lower == "tdie" || lower.find("package") != std::string::npos) return 2;
    return 3;
  }

  std::optional<std::uint64_t> CachedValue() const {
    if (!cached_) return std::nullopt;
    if (cached_zone_) {
      if (RealPath(cached_chip_.alias) != cached_chip_.path ||
          ReadLine(Join(cached_chip_.path, "type")) != cached_chip_.name) return std::nullopt;
    } else if (!cached_chip_.Current() || !cached_chip_.Readable()) return std::nullopt;
    const auto value = ReadUnsigned(Join(cached_chip_.path, cached_->file));
    return value && *value > 0 && *value < 150000 ? value : std::nullopt;
  }

  void Discover() {
    cached_zone_ = false;
    const auto root = Join(paths_.sys, "class/hwmon");
    int best_rank = 100;
    std::uint64_t best_value = 0;
    for (const auto &entry : DirectoryNames(root)) {
      const auto chip = ResolveHwmon(Join(root, entry));
      if (chip.path.empty() || !CpuChip(Lowercase(chip.name)) || !chip.Readable()) continue;
      for (const auto &file : DirectoryNames(chip.path)) {
        if (!StartsWith(file, "temp") || !EndsWith(file, "_input")) continue;
        const auto stem = file.substr(0, file.size() - 6);
        const auto label = ReadLine(Join(chip.path, stem + "_label")).value_or(chip.name);
        const int rank = Rank(Lowercase(chip.name), label);
        if (rank > best_rank) continue;
        const auto value = ReadUnsigned(Join(chip.path, file));
        if (!value || *value == 0 || *value >= 150000 || (rank == best_rank && *value <= best_value)) continue;
        best_rank = rank;
        best_value = *value;
        cached_chip_ = chip;
        cached_ = Sensor{file, entry + "/" + stem, label, "temperature"};
      }
    }
    if (!cached_) DiscoverZone();
    next_discovery_ = cached_ ? Clock::time_point{} : Clock::now() + std::chrono::seconds(30);
  }

  void DiscoverZone() {
    const auto root = Join(paths_.sys, "class/thermal");
    int best_rank = 3;
    std::uint64_t best_value = 0;
    for (const auto &entry : DirectoryNames(root)) {
      if (!StartsWith(entry, "thermal_zone")) continue;
      const auto alias = Join(root, entry);
      const auto path = RealPath(alias);
      if (path.empty()) continue;
      const auto type = ReadLine(Join(path, "type")).value_or("");
      const auto lower = Lowercase(type);
      int rank = 3;
      if (lower == "x86_pkg_temp" || lower == "cpu-thermal") rank = 0;
      if (lower == "tcpu") rank = 1;
      if (lower == "acpitz") rank = 2;
      if (rank >= 3 || rank > best_rank) continue;
      const auto value = ReadUnsigned(Join(path, "temp"));
      if (!value || *value == 0 || *value >= 150000 || (rank == best_rank && *value <= best_value)) continue;
      best_rank = rank;
      best_value = *value;
      cached_chip_ = Hwmon{};
      cached_chip_.alias = alias;
      cached_chip_.path = path;
      cached_chip_.name = type;
      cached_zone_ = true;
      cached_ = Sensor{"temp", entry + "/temp", type, "temperature"};
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
  std::optional<unsigned int> percent, target;
  std::optional<std::uint64_t> rpm;
  std::string mode = "unknown";
  unsigned int minimum = 0, maximum = 100;
  bool controllable = false;
};

struct GpuAdapter {
  std::string id;
  std::string vendor_hex;
  std::string vendor;
  std::string driver;
  std::string name;
  std::string card_path;
  std::string device_alias, device_path, driver_path;
  dev_t device_fs = 0;
  ino_t device_inode = 0;
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

  ~NvidiaProvider() {
    Close();
    if (library_) dlclose(library_);
  }

  void Close() {
    if (initialized_ && shutdown_)
      shutdown_();
    initialized_ = false;
    attempted_ = false;
    // Keep the driver mapped: repeated dlclose/reload leaks its eventfds.
    // NVML sessions still end after every sample, permitting device idle.
  }

  std::vector<NvidiaReading> Read(const std::vector<std::string> &active_ids,
                                  bool sensors = false, bool diagnostic = false) {
    if (active_ids.empty()) return {};
    if (!fixture_.empty()) return ReadFixture();
    if (!Initialize())
      return {};

    std::vector<NvidiaReading> readings;
    for (const auto &id : active_ids) {
      void *device = nullptr;
      if (get_handle_(id.c_str(), &device) != 0 || !device)
        continue;
      NvidiaReading reading;
      reading.id = id;

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
      if (sensors || diagnostic) {
        unsigned int temperature = 0;
        if (get_temperature_ && get_temperature_(device, 0, &temperature) == 0 && temperature < 150)
          reading.temperature = temperature;
        ReadFans(device, reading);
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

  struct NvmlFanSpeedInfo {
    unsigned int version, fan, speed;
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
  GetClock get_fan_policy_ = nullptr, get_target_fan_speed_ = nullptr;
  int (*get_fan_limits_)(void *, unsigned int *, unsigned int *) = nullptr;
  int (*get_fan_rpm_)(void *, NvmlFanSpeedInfo *) = nullptr;

  void ReadFans(void *device, NvidiaReading &reading) const {
    unsigned int count = 0, minimum = 0, maximum = 0;
    if (get_num_fans_ && get_num_fans_(device, &count) == 0) {
      const bool limits = count > 0 && get_fan_limits_ &&
          get_fan_limits_(device, &minimum, &maximum) == 0 && minimum <= maximum &&
          maximum <= 100 && count <= 8;
      for (unsigned int index = 0; index < std::min(count, 8U); ++index) {
        FanReading fan{};
        fan.index = index;
        fan.controllable = limits;
        if (limits) {
          fan.minimum = minimum;
          fan.maximum = maximum;
        }
        unsigned int value = 0;
        if (get_fan_speed_v2_ && get_fan_speed_v2_(device, index, &value) == 0 && value <= 150)
          fan.percent = value;
        else if (!get_fan_speed_v2_ && count == 1 && get_fan_speed_ &&
                 get_fan_speed_(device, &value) == 0 && value <= 150)
          fan.percent = value;
        if (get_fan_policy_ && get_fan_policy_(device, index, &value) == 0 && value <= 1)
          fan.mode = value == 0 ? "auto" : "manual";
        if (get_target_fan_speed_ && get_target_fan_speed_(device, index, &value) == 0 && value <= 150)
          fan.target = value;
        NvmlFanSpeedInfo rpm{(1U << 24) | sizeof(NvmlFanSpeedInfo), index, 0};
        if (get_fan_rpm_ && get_fan_rpm_(device, &rpm) == 0) fan.rpm = rpm.speed;
        reading.fans.push_back(std::move(fan));
      }
    } else if (get_fan_speed_) {
      unsigned int speed = 0;
      if (get_fan_speed_(device, &speed) == 0 && speed <= 150) {
        FanReading fan{};
        fan.percent = speed;
        reading.fans.push_back(fan);
      }
    }
  }

  template <typename Function> Function Symbol(const char *name) {
    return reinterpret_cast<Function>(dlsym(library_, name));
  }

  bool Initialize() {
    if (attempted_)
      return initialized_;
    attempted_ = true;
    if (!library_) library_ = dlopen("libnvidia-ml.so.1", RTLD_NOW | RTLD_LOCAL);
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
    get_fan_policy_ = Symbol<GetClock>("nvmlDeviceGetFanControlPolicy_v2");
    get_target_fan_speed_ = Symbol<GetClock>("nvmlDeviceGetTargetFanSpeed");
    get_fan_limits_ = Symbol<decltype(get_fan_limits_)>("nvmlDeviceGetMinMaxFanSpeed");
    get_fan_rpm_ = Symbol<decltype(get_fan_rpm_)>("nvmlDeviceGetFanSpeedRPM");
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
      reading.id = PciBus(Trim(fields[0]));
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

  void Collect(std::ostream &output, bool sensors = false, bool diagnostic = false) {
    DiscoverAdapters();
    RevalidateAdapters();
    if (!sensors) RefreshDynamicValues();
    ApplyNvidia(sensors, diagnostic);
    if (sensors) {
      for (const auto &gpu : adapters_) {
        if (gpu.driver != "nvidia") continue;
        if (gpu.temperature >= 0)
          output << "temperature\tnvidia/" << gpu.id << "\tNVIDIA\t"
                 << Sanitize(gpu.name) << '\t' << gpu.temperature * 1000
                 << "\tgpu\t" << Sanitize(gpu.name) << '\t' << gpu.id << '\n';
        for (const auto &fan : gpu.fans) {
          if (!output) return;
          FanChannel row;
          row.id = "nv." + ChannelBus(gpu.id) + ".fan" + std::to_string(fan.index);
          row.backend = row.driver = "nvidia";
          row.owner = gpu.name;
          row.label = "fan" + std::to_string(fan.index + 1);
          row.location = gpu.id;
          row.duty = fan.percent;
          row.mode = fan.mode;
          row.rpm = fan.rpm;
          row.minimum = fan.minimum;
          row.maximum = fan.maximum;
          row.controllable = fan.controllable;
          const auto fan_id = "nvidia/" + gpu.id + "/fan" + std::to_string(fan.index);
          if (fan.percent) {
            row.sensor = fan_id;
            output << "fan\t" << fan_id << '\t' << Sanitize(gpu.name) << '\t' << row.label
                   << '\t' << *fan.percent << "\tpercent\tgpu\t" << Sanitize(gpu.name)
                   << '\t' << gpu.id << '\n';
          } else if (fan.rpm) {
            row.sensor = fan_id;
            output << "fan\t" << fan_id << '\t' << Sanitize(gpu.name) << '\t' << row.label
                   << '\t' << *fan.rpm << "\trpm\tgpu\t" << Sanitize(gpu.name)
                   << '\t' << gpu.id << '\n';
          }
          row.Emit(output);
        }
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
    if (diagnostic) {
      for (const auto &gpu : adapters_) {
        output << "gpu-power-state\t" << gpu.id << '\t'
               << ReadLine(Join(gpu.device_path,"power/runtime_status")).value_or("unknown") << '\n';
        if (gpu.temperature >= 0)
          output << "gpu-temperature\t" << gpu.id << '\t' << gpu.temperature << '\n';
        for (const auto &fan : gpu.fans) {
          if (fan.percent) output << "gpu-fan\t" << gpu.id << '\t' << fan.index << '\t' << *fan.percent << '\n';
          if (fan.target) output << "gpu-fan-target\t" << gpu.id << '\t' << fan.index << '\t' << *fan.target << '\n';
        }
      }
    }
    const auto now = std::chrono::duration<double>(
        std::chrono::system_clock::now().time_since_epoch()).count();
    const auto uptime = nvidia_processes_.empty() ? 0 : ParseDouble(UptimeSample(paths_)).value_or(0);
    const auto ticks = SystemValue(_SC_CLK_TCK, 100);
    for (const auto &[gpu, process] : nvidia_processes_) {
      const auto start = ProcessStart(process.pid);
      if (!start) continue;
      if (uptime <= 0 || process.timestamp / 1000000.0 < now - uptime + *start / static_cast<double>(ticks)) continue;
      std::ostringstream row;
      row << "process-gpu\t" << gpu << '\t' << process.pid << '\t' << *start
          << '\t' << process.utilization;
      if (diagnostic) row << '\t' << process.timestamp;
      if (!EmitBoundedRow(output, row.str())) return;
    }
    if (!diagnostic || Clock::now() >= next_diagnostic_drm_) {
      EmitDrmClients(output);
      if (diagnostic) next_diagnostic_drm_ = Clock::now()+std::chrono::seconds(10);
    } else output << "diagnostic-limit\tdrm-process\tnot-due\n";
  }

private:
  struct EngineValue {
    std::string name, kind;
    std::uint64_t busy;
    std::optional<std::uint64_t> total;
    std::uint64_t capacity;
  };
  struct ClientSample {
    std::string client, pdev, driver;
    std::unordered_map<std::string, std::uint64_t> resident;
    std::vector<EngineValue> engines;
  };
  struct FdBatch {
    unsigned int pid;
    std::uint64_t start;
    std::vector<std::string> paths;
  };
  static constexpr std::size_t kFdVisitLimit = 16384, kFdPathLimit = 512;
  static constexpr std::size_t kFdinfoLimit = 8191, kFdinfoRowLimit = 128, kDrmRowLimit = 2048;
  static constexpr auto kDrmBudget = std::chrono::milliseconds(150);

  Paths paths_;
  NvidiaProvider nvidia_;
  bool adapters_discovered_ = false;
  Clock::time_point next_adapter_discovery_{};
  std::vector<GpuAdapter> adapters_;
  std::vector<FdBatch> fdinfo_paths_;
  std::vector<std::pair<std::string, GpuProcessReading>> nvidia_processes_;

  std::optional<std::uint64_t> ProcessStart(unsigned int pid) const {
    const auto raw = ReadRecord(Join(Join(paths_.proc, std::to_string(pid)), "stat"), 8191);
    if (!raw) return std::nullopt;
    const auto begin = raw->find('('), end = raw->rfind(')');
    if (begin == std::string::npos || end == std::string::npos || begin >= end ||
        end + 1 >= raw->size() || (*raw)[end + 1] != ' ' ||
        ParseUnsigned(Trim(raw->substr(0, begin))) != pid) return std::nullopt;
    const auto fields = SplitWhitespace(raw->substr(end + 2));
    const auto start = fields.size() > 19 ? ParseUnsigned(fields[19]) : std::nullopt;
    return start && *start > 0 ? start : std::nullopt;
  }

  static bool EmitBoundedRow(std::ostream &output, const std::string &row) {
    const auto used = output.tellp();
    if (used < 0 || row.size() + 1 > kFrameLimit - static_cast<std::size_t>(used)) return false;
    output << row << '\n';
    return output.good();
  }

  Clock::time_point next_fd_discovery_{};
  Clock::time_point next_diagnostic_drm_{};
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
    if (adapters_discovered_ && Clock::now() < next_adapter_discovery_) return;
    adapters_discovered_ = true;
    next_adapter_discovery_ = Clock::now() + std::chrono::seconds(30);
    auto previous = std::move(adapters_);
    adapters_.clear();
    std::unordered_set<std::string> seen;
    const auto add = [&](const std::string &alias, const std::string &card, bool headless) {
      const auto device = RealPath(alias);
      struct stat identity{};
      if (device.empty() || stat(device.c_str(), &identity) != 0) return;
      const auto bus = PciBus(BaseName(device));
      const auto driver = DriverPath(device);
      if (headless && (bus.empty() || BaseName(driver) != "nvidia")) return;
      const auto id = bus.empty() ? BaseName(card) : bus;
      if (id.empty() || !seen.insert(id).second) return;

      GpuAdapter gpu;
      gpu.id = id;
      gpu.card_path = card.empty() ? "" : RealPath(card);
      gpu.device_alias = alias;
      gpu.device_path = device;
      gpu.driver_path = driver;
      gpu.device_fs = identity.st_dev;
      gpu.device_inode = identity.st_ino;
      gpu.vendor_hex = NormalizeHex(ReadLine(Join(device, "vendor")).value_or(""));
      gpu.driver = driver.empty() ? "unknown" : BaseName(driver);
      gpu.vendor = gpu.driver == "nvidia" ? "NVIDIA" : GpuVendor(gpu.vendor_hex);
      gpu.name = ReadLine(Join(device, "product_name")).value_or("");
      if (gpu.name.empty()) {
        const auto product = NormalizeHex(ReadLine(Join(device, "device")).value_or(""));
        gpu.name = PciDeviceName(gpu.vendor_hex, product);
      }
      if (gpu.name.empty()) gpu.name = gpu.vendor + " GPU";
      const auto old = std::find_if(previous.begin(), previous.end(),
                                    [&](const auto &entry) { return entry.id == id; });
      if (old != previous.end() && !SameDevice(*old, gpu)) {
        InvalidateDiscovery();
        return;
      }
      adapters_.push_back(std::move(gpu));
    };

    const auto drm = Join(paths_.sys, "class/drm");
    for (const auto &name : DirectoryNames(drm)) {
      if (!StartsWith(name, "card") || !IsDigits(std::string_view(name).substr(4))) continue;
      const auto card = Join(drm, name);
      add(Join(card, "device"), card, false);
    }
    const auto pci = Join(paths_.sys, "bus/pci/devices");
    const auto nvidia_proc = Join(paths_.proc, "driver/nvidia/gpus");
    for (const auto &name : DirectoryNames(nvidia_proc)) {
      const auto bus = PciBus(name);
      if (!bus.empty() && !seen.count(bus)) add(Join(pci, bus), "", true);
    }
    const auto nvidia_pci = Join(paths_.sys, "bus/pci/drivers/nvidia");
    for (const auto &name : DirectoryNames(nvidia_pci)) {
      const auto bus = PciBus(name);
      if (!bus.empty() && !seen.count(bus)) add(Join(nvidia_pci, name), "", true);
    }
    for (const auto &name : DirectoryNames(pci)) {
      const auto bus = PciBus(name);
      if (!bus.empty() && !seen.count(bus)) add(Join(pci, name), "", true);
    }
  }

  static bool SameDevice(const GpuAdapter &old, const GpuAdapter &current) {
    return old.device_path == current.device_path && old.driver_path == current.driver_path &&
           old.device_fs == current.device_fs && old.device_inode == current.device_inode &&
           old.vendor_hex == current.vendor_hex;
  }

  void InvalidateDiscovery() {
    next_adapter_discovery_ = {};
    next_fd_discovery_ = {};
    fdinfo_paths_.clear();
  }

  void RevalidateAdapters() {
    const auto invalid = std::remove_if(adapters_.begin(), adapters_.end(), [](const GpuAdapter &gpu) {
      struct stat identity{};
      const auto device = RealPath(gpu.device_alias);
      return device != gpu.device_path || DriverPath(device) != gpu.driver_path ||
             stat(device.c_str(), &identity) != 0 || identity.st_dev != gpu.device_fs ||
             identity.st_ino != gpu.device_inode;
    });
    // Omit the old identity for this sample so consumers drop its counter baselines.
    if (invalid != adapters_.end()) {
      adapters_.erase(invalid, adapters_.end());
      InvalidateDiscovery();
    }
  }

  void RefreshDynamicValues() {
    for (auto &gpu : adapters_) {
      gpu.utilization = -1;
      gpu.memory_used = -1;
      gpu.memory_total = -1;
      gpu.memory_kind = "unknown";
      gpu.frequency_mhz = -1;

      // Do not reset an autosuspend timer by reading telemetry on a sleeping dGPU.
      if (gpu.driver == "nvidia" || !RuntimeReadable(gpu.device_path)) continue;

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
            gpu.memory_total = static_cast<std::int64_t>(*total);
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

  void ApplyNvidia(bool sensors, bool diagnostic = false) {
    nvidia_processes_.clear();
    for (auto &gpu : adapters_) { gpu.temperature = -1; gpu.fans.clear(); }
    std::vector<std::string> active_ids;
    for (const auto &gpu : adapters_) {
      if (gpu.driver == "nvidia" && !PciBus(gpu.id).empty() &&
          RuntimeReadable(gpu.device_path, true))
        active_ids.push_back(gpu.id);
    }
    for (const auto &reading : nvidia_.Read(active_ids, sensors, diagnostic)) {
      auto found =
          std::find_if(adapters_.begin(), adapters_.end(),
                       [&](const auto &gpu) { return gpu.id == reading.id; });
      if (found == adapters_.end() ||
          std::find(active_ids.begin(), active_ids.end(), reading.id) == active_ids.end()) continue;
      for (const auto &process : reading.processes)
        nvidia_processes_.emplace_back(reading.id, process);
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

  void DiscoverFdinfoPaths(Clock::time_point deadline) {
    fdinfo_paths_.clear();
    next_fd_discovery_ = Clock::now() + discovery_interval_;
    DIR *proc = opendir(paths_.proc.c_str());
    if (!proc) return;
    std::size_t pids_visited = 0, fds_visited = 0, retained = 0;
    const auto has_budget = [&] {
      return fds_visited < kFdVisitLimit && retained < kFdPathLimit && Clock::now() < deadline;
    };
    while (pids_visited++ < 8192 && has_budget()) {
      const auto *entry = readdir(proc);
      if (!entry) break;
      const auto pid = ParseUnsigned(entry->d_name);
      if (!pid || *pid == 0 || *pid == static_cast<std::uint64_t>(getpid()) || *pid > UINT_MAX) continue;
      const auto process = Join(paths_.proc, entry->d_name);
      const auto fd_root = Join(process, "fd");
      const auto info_root = Join(process, "fdinfo");
      DIR *directory = opendir(fd_root.c_str());
      if (!directory) continue;
      std::optional<std::uint64_t> start;
      std::vector<std::string> paths;
      while (has_budget()) {
        const auto *fd = readdir(directory);
        if (!fd) break;
        ++fds_visited;
        if (!IsDigits(fd->d_name)) continue;
        const auto link = Join(fd_root, fd->d_name);
        std::array<char, PATH_MAX> target{};
        const auto length = readlink(link.c_str(), target.data(), target.size());
        if (length <= 0 || !StartsWith(std::string_view(target.data(), static_cast<std::size_t>(length)), "/dev/dri/"))
          continue;
        if (paths.empty()) {
          start = ProcessStart(static_cast<unsigned int>(*pid));
          if (!start) break;
        }
        paths.push_back(Join(info_root, fd->d_name));
        ++retained;
      }
      closedir(directory);
      if (!paths.empty() && ProcessStart(static_cast<unsigned int>(*pid)) == start)
        fdinfo_paths_.push_back({static_cast<unsigned int>(*pid), *start, std::move(paths)});
    }
    closedir(proc);
  }

  static std::optional<std::uint64_t> ScaledCounter(std::uint64_t amount, std::uint64_t scale) {
    if (amount > UINT64_MAX / scale) return std::nullopt;
    return amount * scale;
  }

  static std::optional<std::uint64_t> MemoryCounter(std::uint64_t amount, const std::string &unit) {
    if (unit == "KiB") return ScaledCounter(amount, 1024);
    if (unit == "MiB") return ScaledCounter(amount, 1024 * 1024);
    if (unit == "GiB") return ScaledCounter(amount, 1024 * 1024 * 1024);
    return unit.empty() || unit == "B" ? std::optional<std::uint64_t>(amount) : std::nullopt;
  }

  static std::optional<ClientSample> ParseFdinfo(const std::string &path) {
    const auto raw = ReadRecord(path, kFdinfoLimit);
    if (!raw) return std::nullopt;
    struct Counters {
      std::optional<std::uint64_t> time, cycles, total, frequency;
      std::uint64_t capacity = 1;
    };
    ClientSample sample;
    std::unordered_map<std::string, Counters> engines;
    std::istringstream stream(*raw);
    std::string line;
    std::size_t rows = 0;
    while (std::getline(stream, line)) {
      if (++rows > kFdinfoRowLimit) return std::nullopt;
      const auto colon = line.find(':');
      if (colon == std::string::npos || colon > 96) continue;
      const std::string_view key(line.data(), colon);
      if (!StartsWith(key, "drm-") ||
          std::any_of(key.begin(), key.end(), [](unsigned char ch) { return ch <= ' ' || ch == 127; }))
        continue;
      const auto fields = SplitWhitespace(line.substr(colon + 1));
      if (fields.empty() || fields.size() > 2) continue;
      const auto value = ParseUnsigned(fields[0]);
      const auto unit = fields.size() > 1 ? fields[1] : "";
      if (key == "drm-client-id" && value && unit.empty()) {
        sample.client = std::to_string(*value);
      } else if (key == "drm-pdev" && unit.empty()) {
        sample.pdev = PciBus(fields[0]);
      } else if (key == "drm-driver" && unit.empty() && fields[0].size() <= 64) {
        sample.driver = fields[0];
      } else if (value) {
        constexpr std::string_view resident = "drm-resident-", memory = "drm-memory-";
        if (StartsWith(key, resident) || StartsWith(key, memory)) {
          const bool modern = StartsWith(key, resident);
          const auto region = std::string(key.substr(modern ? resident.size() : memory.size()));
          const auto bytes = MemoryCounter(*value, unit);
          if (bytes && !region.empty()) {
            if (modern) sample.resident[region] = *bytes;
            else sample.resident.emplace(region, *bytes);
          }
          continue;
        }
        auto counter = [&](std::string_view prefix) -> Counters * {
          if (!StartsWith(key, prefix) || key.size() == prefix.size()) return nullptr;
          return &engines[std::string(key.substr(prefix.size()))];
        };
        if (auto *engine = counter("drm-engine-capacity-")) {
          if (unit.empty() && *value > 0) engine->capacity = *value;
        } else if (auto *engine = counter("drm-total-cycles-")) {
          if (unit.empty()) engine->total = value;
        } else if (auto *engine = counter("drm-cycles-")) {
          if (unit.empty()) engine->cycles = value;
        } else if (auto *engine = counter("drm-maxfreq-")) {
          if (unit == "Hz" || unit.empty()) engine->frequency = value;
          else if (unit == "KHz" || unit == "kHz") engine->frequency = ScaledCounter(*value, 1000);
          else if (unit == "MHz") engine->frequency = ScaledCounter(*value, 1000000);
        } else if (auto *engine = counter("drm-engine-")) {
          if (unit == "ns" || unit.empty()) engine->time = value;
        }
      }
    }
    if (sample.client.empty() || sample.pdev.empty()) return std::nullopt;
    for (const auto &[name, engine] : engines) {
      std::optional<EngineValue> cycles;
      if (engine.cycles && engine.total)
        cycles = EngineValue{name, "cycles", *engine.cycles, engine.total, engine.capacity};
      else if (engine.cycles && engine.frequency && *engine.frequency > 0) {
        // Normalize to nanoseconds at maximum frequency for the v1 time formula.
        const long double ns = *engine.cycles * 1e9L / *engine.frequency;
        if (ns < static_cast<long double>(UINT64_MAX))
          cycles = EngineValue{name, "maxfreq", static_cast<std::uint64_t>(ns), std::nullopt, engine.capacity};
      }
      // Distinct names keep the consumer from summing two readings of the same engine.
      if (engine.time)
        sample.engines.push_back({cycles ? name + "/time" : name, "time", *engine.time,
                                  std::nullopt, engine.capacity});
      if (cycles) sample.engines.push_back(std::move(*cycles));
    }
    return sample;
  }

  void EmitDrmClients(std::ostream &output) {
    if (adapters_.empty()) return;
    const auto begin = Clock::now(), deadline = begin + kDrmBudget;
    std::unordered_map<std::string, std::string> known;
    for (const auto &gpu : adapters_) {
      if (RuntimeReadable(gpu.device_path, gpu.driver == "nvidia"))
        known.emplace(gpu.id, gpu.driver);
    }
    if (known.empty()) return;
    if (begin >= next_fd_discovery_) DiscoverFdinfoPaths(begin + kDrmBudget / 2);

    std::unordered_set<std::string> clients;
    std::unordered_map<std::string, std::uint64_t> dedicated, shared;
    std::size_t rows = 0;
    const auto emit = [&](const std::string &row) {
      return rows++ < kDrmRowLimit && Clock::now() < deadline && EmitBoundedRow(output, row);
    };

    for (const auto &batch : fdinfo_paths_) {
      if (Clock::now() >= deadline) break;
      const auto start = ProcessStart(batch.pid);
      if (start != batch.start) {
        next_fd_discovery_ = {};
        continue;
      }
      std::vector<ClientSample> samples;
      for (const auto &path : batch.paths) {
        if (Clock::now() >= deadline) break;
        auto sample = ParseFdinfo(path);
        if (!sample) continue;
        const auto gpu = known.find(sample->pdev);
        if (gpu != known.end() && (sample->driver.empty() || gpu->second == sample->driver))
          samples.push_back(std::move(*sample));
      }
      if (ProcessStart(batch.pid) != start) {
        next_fd_discovery_ = {};
        continue;
      }
      std::unordered_set<std::string> process_clients;
      for (const auto &sample : samples) {
        const auto client = sample.pdev + "\t" + sample.client;
        if (!process_clients.insert(client).second) continue;
        const bool first = clients.insert(client).second;
        for (const auto &engine : sample.engines) {
          const auto fields = "\t" + client + "\t" + engine.name + "\t" +
              std::to_string(engine.busy) + "\t" +
              (engine.total ? std::to_string(*engine.total) : "-1") + "\t" +
              std::to_string(engine.capacity) + "\t" + engine.kind;
          if (first && !emit("engine" + fields)) return;
          if (!emit("process-engine" + fields + "\t" + std::to_string(batch.pid) +
                    "\t" + std::to_string(*start))) return;
        }
        if (!first) continue;
        for (const auto &[region, bytes] : sample.resident) {
          const bool local = region.find("vram") != std::string::npos || region.find("local") != std::string::npos;
          auto &total = (local ? dedicated : shared)[sample.pdev];
          total += std::min(bytes, UINT64_MAX - total);
        }
      }
    }

    for (const auto &[id, bytes] : dedicated) {
      if (!emit("gpu-memory\t" + id + "\tvram\t" + std::to_string(bytes))) return;
    }
    for (const auto &[id, bytes] : shared) {
      if (!emit("gpu-memory\t" + id + "\tshared\t" + std::to_string(bytes))) return;
    }
  }

};

#include "FastDiagnostics.h"
#include "MemoryWatch.h"

class Sampler {
public:
  explicit Sampler(Paths paths)
      : resources_(paths), processes_(paths), thermals_(paths), storage_(paths),
        gpus_(paths), journal_(paths), sensor_journal_(paths, "sensors"),
        fast_(paths, resources_, processes_, thermals_, gpus_), memory_watch_(paths) {}

  void Tick() { fast_.Tick(); }
  int Timeout() const { return fast_.Timeout(); }

  void Collect(const std::string &kind, std::ostream &destination) {
    FrameBuffer frame;
    std::ostream output(&frame);
    input_overflow = false;
    if (StartsWith(kind, "capture-")) {
      if (kind=="capture-250") fast_.Start(250);
      else if(kind=="capture-500") fast_.Start(500);
      else if(kind=="capture-1000") fast_.Start(1000);
      else if(kind=="capture-off") fast_.Stop();
      else if(kind=="capture-marker") fast_.Marker();
      else if(kind=="capture-flush") fast_.Flush();
      fast_.Status(output);
    } else if (fast_.Cached(kind, output)) {
      // A native diagnostic tick already owns this sample.
    } else if (kind == "sensors-on" || kind == "sensors-off") {
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
    } else if (kind == "memory-watch")
      memory_watch_.Collect(output);
    else if (kind == "resources")
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
      if (!sensor_journal_.error.empty()) {
        const auto error = "recording-error\t" + sensor_journal_.error + "\n";
        if (error.size() <= kFrameLimit - frame.data.size()) frame.data += error;
      }
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
  FastDiagnostics fast_;
  MemoryWatchCollector memory_watch_;
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
    const int ready=poll(&input,1,sampler.Timeout());
    if(ready<0 && errno==EINTR) continue;
    if(ready<0) break;
    sampler.Tick();
    if(ready==0) continue;
    char ch=0;const auto n=read(STDIN_FILENO,&ch,1);
    if(n<=0) break;
    if(ch!='\n') { if(request.size()>=31) break;request+=ch;continue; }
    request=Trim(request);
    if (request != "memory-watch" && request != "glance" && request != "resources" && request != "processes" &&
        request != "thermals" && request != "sensors" && request != "sensors-on" && request != "sensors-off" && request != "gpus" && request != "storage" &&
        request != "journal-on" && request != "journal-off" && request != "journal" && request != "diagnostics" &&
        request != "capture-250" && request != "capture-500" && request != "capture-1000" &&
        request != "capture-off" && request != "capture-status" && request != "capture-marker" && request != "capture-flush") {
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
