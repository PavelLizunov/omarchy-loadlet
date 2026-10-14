// Included inside the sampler namespace. Owned by the existing reader; no daemon.
// Records are bounded, local and opt-in. CPU percentages are not electrical watts.
std::string JsonString(const std::string &value) {
  std::string out = "\"";
  for (unsigned char c : value) {
    if (c == '"' || c == '\\') { out += '\\'; out += static_cast<char>(c); }
    else if (c < 32 || c >= 128) {
      // Escape bytes explicitly. Non-ASCII process names are represented as byte
      // escapes and decoded by the report helper; arbitrary proc bytes stay safe.
      char b[7]; std::snprintf(b, sizeof(b), "\\u%04x", c); out += b;
    } else out += static_cast<char>(c);
  }
  return out + '"';
}

std::string JsonNumber(const std::optional<std::uint64_t> &value) {
  return value ? std::to_string(*value) : "null";
}

std::string DiagnosticContext(const Paths &paths) {
  std::ostringstream out;
  out << "{\"sample_uptime\":" << UptimeSample(paths)
      << ",\"page_size_bytes\":" << SystemValue(_SC_PAGESIZE,4096)
      << ",\"loadavg\":" << JsonString(ReadLine(Join(paths.proc, "loadavg")).value_or(""));
  out << ",\"psi\":{";
  bool first = true;
  for (const auto &kind : {"cpu", "memory", "io"}) {
    if (!first) out << ',';
    first = false;
    out << JsonString(kind) << ':';
    auto raw = ReadText(Join(paths.proc, std::string("pressure/") + kind));
    out << (raw ? JsonString(*raw) : "null");
  }
  out << "},\"vmstat\":{";
  auto vm = ReadText(Join(paths.proc, "vmstat"));
  first = true;
  if (vm) {
    std::istringstream stream(*vm); std::string key, value;
    while (stream >> key >> value) {
      if (key != "pswpin" && key != "pswpout" && key != "oom_kill" && key != "pgmajfault") continue;
      if (!first) out << ',';
      first = false;
      out << JsonString(key) << ':' << JsonNumber(ParseUnsigned(value));
    }
  }
  out << "},\"boost\":" << JsonNumber(ReadUnsigned(Join(paths.sys, "devices/system/cpu/cpufreq/boost")))
      << ",\"platform_profile\":" << JsonString(ReadLine(Join(paths.sys, "firmware/acpi/platform_profile")).value_or(""))
      << ",\"platform_choices\":" << JsonString(ReadLine(Join(paths.sys, "firmware/acpi/platform_profile_choices")).value_or(""))
      << ",\"policies\":[";
  first = true; unsigned int count = 0;
  for (const auto &name : DirectoryNames(Join(paths.sys, "devices/system/cpu/cpufreq"))) {
    if (!StartsWith(name, "policy") || !IsDigits(name.substr(6))) continue;
    if (++count > 64) break;
    if (!first) out << ',';
    first = false;
    const auto folder = Join(paths.sys, "devices/system/cpu/cpufreq/" + name);
    out << "{\"id\":" << JsonString(name);
    for (const auto &key : {"scaling_cur_freq", "scaling_min_freq", "scaling_max_freq", "cpuinfo_min_freq", "cpuinfo_max_freq", "amd_pstate_lowest_nonlinear_freq"})
      out << ',' << JsonString(key) << ':' << JsonNumber(ReadUnsigned(Join(folder, key)));
    for (const auto &key : {"scaling_driver", "scaling_governor", "scaling_available_governors", "energy_performance_preference", "energy_performance_available_preferences", "related_cpus"})
      out << ',' << JsonString(key) << ':' << JsonString(ReadLine(Join(folder, key)).value_or(""));
    out << '}';
  }
  out << "],\"policies_truncated\":" << (count > 64 ? "true" : "false") << ",\"power_supplies\":[";
  first = true; count = 0;
  for (const auto &name : DirectoryNames(Join(paths.sys, "class/power_supply"))) {
    if (++count > 16) break;
    const auto folder = Join(paths.sys, "class/power_supply/" + name);
    if (!first) out << ',';
    first = false;
    out << "{\"id\":" << JsonString(name);
    for (const auto &key : {"type", "status"})
      out << ',' << JsonString(key) << ':' << JsonString(ReadLine(Join(folder, key)).value_or(""));
    out << ",\"online\":" << JsonNumber(ReadUnsigned(Join(folder, "online"))) << '}';
  }
  out << "],\"scope\":\"CPU/procfs/sysfs only; GPU, fan and package watts not observed\"}";
  return out.str();
}

class DiagnosticJournal {
public:
  explicit DiagnosticJournal(Paths paths) : paths_(std::move(paths)) {
    boot_ = ReadLine(Join(paths_.proc, "sys/kernel/random/boot_id")).value_or("");
  }
  ~DiagnosticJournal() { Disable(); }
  std::string error;
  bool enabled = false;

  bool Enable() {
    if (enabled) return true;
    error.clear();
    const auto base = EnvOr("XDG_STATE_HOME", "");
    const auto home = EnvOr("HOME", "");
    const auto target = base.empty() ? Join(home, ".local/state") : base;
    dir_ = OpenDirectory(target);
    if (dir_ < 0) return Fail("unsafe_or_unavailable_state_directory");
    for (const auto &name : {"omarchy", "activity-lite", "journal"}) {
      const int child = ChildDirectory(dir_, name);
      close(dir_); dir_ = child;
      if (dir_ < 0) return Fail("unsafe_or_unavailable_journal_directory");
    }
    lock_ = openat(dir_, ".writer.lock", O_CREAT | O_RDWR | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC, 0600);
    if (lock_ < 0 || !OwnedFile(lock_) || flock(lock_, LOCK_EX | LOCK_NB) != 0)
      return Fail("journal_writer_busy_or_unsafe");
    enabled = true;
    last_flush_ = Clock::now();
    return true;
  }
  void Disable() {
    if (enabled) Flush();
    enabled = false;
    if (file_ >= 0) close(file_);
    if (lock_ >= 0) close(lock_);
    if (dir_ >= 0) close(dir_);
    file_ = lock_ = dir_ = -1;
    buffer_.clear();
    previous_total_=previous_idle_=0;previous_cpu_sample_=0;
    previous_processes_.clear();
    process_sample_="null";processes_truncated_=false;
    resource_at_=thermal_at_=process_at_=context_at_=sample_at_=Clock::time_point{};
  }

  void Observe(const std::string &kind, const std::string &frame) {
    if (!enabled) return;
    const auto now = Clock::now();
    if(StartsWith(frame,"error\t")) {
      collection_error_="capacity_or_invalid_collection";
      const auto stamp=std::chrono::duration_cast<std::chrono::seconds>(std::chrono::system_clock::now().time_since_epoch()).count();
      const auto event="{\"schema\":1,\"time\":"+std::to_string(stamp)+",\"boot_id\":"+JsonString(boot_)+",\"event\":\"collection_error\",\"kind\":"+JsonString(kind)+"}\n";
      if(buffer_.size()+event.size()<=131072) buffer_+=event;
    }
    else if(kind=="glance" || kind=="resources") collection_error_.clear();
    if (kind == "glance" || kind == "resources") {
      if(frame.find("schema\tactivity-resources\t1\n")!=0) {cpu_="null";memory_="null";resource_at_={};return;}
      ParseResources(frame);
    }
    if (kind == "thermals") {
      if(frame.find("schema\tactivity-thermals\t1\n")!=0) {temperature_="null";thermal_at_={};return;}
      ParseThermal(frame);
    }
    if (kind == "processes" && (process_at_ == Clock::time_point{} || now - process_at_ >= std::chrono::seconds(30))) {
    if(frame.find("schema\tactivity-processes\t1\n")!=0) {processes_="null";process_at_={};previous_processes_.clear();return;}
      ParseProcesses(frame); process_at_ = now;
    }
  }
  std::string Context() {
    if(context_at_!=Clock::time_point{} && Clock::now()-context_at_<std::chrono::seconds(60)) return context_;
    context_ = DiagnosticContext(paths_); context_at_ = Clock::now();
    if (context_.size() > 10000) { context_ = "null"; error = "context_capacity"; }
    return context_;
  }
  void Sample() {
    if (!enabled) return;
    const auto now = Clock::now();
    if (sample_at_ != Clock::time_point{} && now - sample_at_ < std::chrono::seconds(15)) return;
    sample_at_ = now;
    const auto seconds = std::chrono::duration_cast<std::chrono::seconds>(std::chrono::system_clock::now().time_since_epoch()).count();
    auto age = [&](Clock::time_point at) -> std::string {
      return at == Clock::time_point{} ? "null" : std::to_string(std::chrono::duration_cast<std::chrono::milliseconds>(now - at).count());
    };
    auto valid = [&](Clock::time_point at, int limit) { return at != Clock::time_point{} && now - at < std::chrono::seconds(limit); };
    std::ostringstream record;
    record << "{\"schema\":1,\"time\":" << seconds << ",\"boot_id\":" << JsonString(boot_)
      << ",\"uptime\":" << UptimeSample(paths_) << ",\"cpu_pct\":" << (valid(resource_at_,35) ? cpu_ : "null")
      << ",\"collection_error\":" << JsonString(collection_error_)
      << ",\"cpu_window_seconds\":" << cpu_window_
      << ",\"memory\":" << (valid(resource_at_,35) ? memory_ : "null")
      << ",\"temperature_c\":" << (valid(thermal_at_,35) ? temperature_ : "null")
      << ",\"resource_age_ms\":" << age(resource_at_) << ",\"thermal_age_ms\":" << age(thermal_at_)
      << ",\"process_age_ms\":" << age(process_at_) << ",\"context_age_ms\":" << age(context_at_)
      << ",\"process_sample_uptime\":" << process_sample_ << ",\"processes_truncated\":" << (processes_truncated_?"true":"false")
      << ",\"processes\":" << (valid(process_at_,65) ? processes_ : "null")
      << ",\"context\":" << (valid(context_at_,125) ? context_ : "null") << "}\n";
    if (record.str().size() > 32768 || buffer_.size() + record.str().size() > 131072) { error = "journal_record_capacity"; return; }
    buffer_ += record.str();
    if (now - last_flush_ >= std::chrono::seconds(60) || buffer_.size() >= 49152) Flush();
  }

private:
  friend struct DiagnosticJournalChecks;
  Paths paths_;
  std::string boot_, buffer_, file_name_, collection_error_, cpu_window_="null", memory_ = "null", cpu_ = "null", temperature_ = "null", processes_ = "null", context_ = "null";
  int dir_ = -1, lock_ = -1, file_ = -1;
  std::size_t file_size_ = 0;
  Clock::time_point file_at_{}, last_flush_{}, sample_at_{}, resource_at_{}, thermal_at_{}, process_at_{}, context_at_{};
  std::uint64_t previous_total_ = 0, previous_idle_ = 0;
  double previous_cpu_sample_ = 0;
  std::string process_sample_="null";
  bool processes_truncated_=false;
  struct Process { std::uint64_t pid=0,start=0,ticks=0,rss=0; std::string name,state; double sample=0,cpu=-1,growth=0,state_since=0; };
  std::unordered_map<std::string,Process> previous_processes_;

  bool Fail(const char *message) { error = message; Disable(); return false; }
  static bool OwnedFile(int fd) {
    struct stat s{};
    return fstat(fd,&s)==0 && S_ISREG(s.st_mode) && s.st_uid==getuid() && s.st_nlink==1 && (s.st_mode & 0077)==0;
  }
  static int ChildDirectory(int parent, const char *name) {
    if (mkdirat(parent,name,0700)!=0 && errno!=EEXIST) return -1;
    const int fd = openat(parent,name,O_RDONLY|O_DIRECTORY|O_NOFOLLOW|O_CLOEXEC);
    struct stat s{};
    if (fd < 0) return -1;
    if (fstat(fd,&s)!=0 || s.st_uid!=getuid() || (s.st_mode & 0022)!=0) { close(fd); return -1; }
    return fd;
  }
  static int OpenDirectory(const std::string &path) {
    if (path.empty() || path.front()!='/') return -1;
    int fd=open("/",O_RDONLY|O_DIRECTORY|O_CLOEXEC);
    std::istringstream stream(path); std::string part;
    while (std::getline(stream,part,'/')) {
      if (part.empty()) continue;
      if (part=="." || part=="..") { close(fd); return -1; }
      int child=openat(fd,part.c_str(),O_RDONLY|O_DIRECTORY|O_NOFOLLOW|O_CLOEXEC);
      if (child<0 && errno==ENOENT) child=ChildDirectory(fd,part.c_str());
      close(fd); fd=child;
      if (fd<0) return -1;
    }
    struct stat s{};
    if (fstat(fd,&s)!=0 || s.st_uid!=getuid() || (s.st_mode & 0022)!=0) { close(fd); return -1; }
    return fd;
  }
  bool Prune(std::size_t upcoming) {
    struct Entry { std::string name; std::size_t size; time_t modified; };
    std::vector<Entry> entries; std::size_t total=0;
    DIR *directory=fdopendir(dup(dir_));
    if (!directory) return false;
    rewinddir(directory);
    unsigned int seen=0;
    while (auto *entry=readdir(directory)) {
      if (++seen>4096) { closedir(directory); return false; }
      std::string name(entry->d_name);
      if (!StartsWith(name,"samples-") || !EndsWith(name,".jsonl")) continue;
      struct stat s{};
      if (fstatat(dir_,name.c_str(),&s,AT_SYMLINK_NOFOLLOW)!=0 || !S_ISREG(s.st_mode) || s.st_uid!=getuid() || s.st_nlink!=1 || s.st_size<0 || static_cast<std::uint64_t>(s.st_size)>20*1024*1024 || total>20*1024*1024*2ULL) { closedir(directory); return false; }
      entries.push_back({name,static_cast<std::size_t>(s.st_size),s.st_mtime}); total+=static_cast<std::size_t>(s.st_size);
    }
    closedir(directory);
    std::sort(entries.begin(),entries.end(),[](const Entry &a,const Entry &b){return a.name<b.name;});
    const auto cutoff=std::time(nullptr)-7*24*60*60;
    for (const auto &entry:entries) {
      const auto end=entry.name.find('-',8);
      auto created=end==std::string::npos ? std::nullopt : ParseUnsigned(entry.name.substr(8,end-8));
      const bool recent=entry.modified>=cutoff && (!created || *created/1000000000ULL>=static_cast<std::uint64_t>(cutoff));
      if (recent && total+upcoming<=20*1024*1024) continue;
      if (entry.name==file_name_ && file_>=0) { close(file_);file_=-1;file_name_.clear();file_size_=0; }
      if (unlinkat(dir_,entry.name.c_str(),0)!=0) return false;
      total-=entry.size;
    }
    return total+upcoming<=20*1024*1024;
  }
  void Flush() {
    if (buffer_.empty()) return;
    if (file_ >= 0 && (file_size_ + buffer_.size() > 1024*1024 || Clock::now()-file_at_>=std::chrono::hours(1))) { close(file_); file_=-1; }
    if (!Prune(buffer_.size())) { error="journal_retention_failed"; buffer_.clear(); return; }
    if (file_<0) {
      const auto ns=std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::system_clock::now().time_since_epoch()).count();
      file_name_="samples-"+std::to_string(ns)+"-"+std::to_string(getpid())+".jsonl";
      file_=openat(dir_,file_name_.c_str(),O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW|O_CLOEXEC,0600); file_size_=0;file_at_=Clock::now();
    }
    if (file_<0 || !OwnedFile(file_)) { error="journal_open_failed"; buffer_.clear(); return; }
    std::size_t done=0;
    while (done<buffer_.size()) {
      const auto n=write(file_,buffer_.data()+done,buffer_.size()-done);
      if (n<0 && errno==EINTR) continue;
      if (n<=0) { error="journal_write_failed"; break; }
      done+=static_cast<std::size_t>(n);
    }
    if(done!=buffer_.size()) {
      // Discard an incomplete batch so a truncated JSON line cannot corrupt the
      // next append. Original completed records are retained.
      if(ftruncate(file_,static_cast<off_t>(file_size_))!=0) { close(file_);file_=-1; }
      else lseek(file_,static_cast<off_t>(file_size_),SEEK_SET);
    } else file_size_+=done;
    if (done==buffer_.size()) error.clear();
    buffer_.clear(); last_flush_=Clock::now();
  }
  void ParseResources(const std::string &frame) {
    std::istringstream stream(frame); std::string line; double sample=0;
    cpu_="null";memory_="null";cpu_window_="null";
    while (std::getline(stream,line)) {
      const auto f=SplitWhitespace(line);
      if (f.size()>=2 && f[0]=="sample") sample=ParseDouble(f[1]).value_or(0);
      if (f.size()>=4 && f[0]=="cpu" && f[1]=="cpu") {
        auto total=ParseUnsigned(f[2]), idle=ParseUnsigned(f[3]);
        cpu_="null";
        if (total && idle) {
          if (previous_cpu_sample_>0 && sample>previous_cpu_sample_ && sample-previous_cpu_sample_<=35 && *total>previous_total_ && *idle>=previous_idle_ && *idle-previous_idle_<=*total-previous_total_) {
            cpu_=std::to_string(100.0*(1.0-static_cast<double>(*idle-previous_idle_)/static_cast<double>(*total-previous_total_)));
            cpu_window_=std::to_string(sample-previous_cpu_sample_);
          }
          previous_total_=*total;previous_idle_=*idle;previous_cpu_sample_=sample;
        }
      }
      if (f.size()>=6 && f[0]=="memory") {
        auto total=ParseUnsigned(f[1]), available=ParseUnsigned(f[2]), swap=ParseUnsigned(f[3]), free=ParseUnsigned(f[4]);
        if(total && *total>0 && available && *available<=*total && swap && free && *free<=*swap)
          memory_="{\"total_kib\":"+JsonNumber(total)+",\"available_kib\":"+JsonNumber(available)+",\"swap_total_kib\":"+JsonNumber(swap)+",\"swap_free_kib\":"+JsonNumber(free)+"}";
      }
    }
    resource_at_=Clock::now();
  }
  void ParseThermal(const std::string &frame) {
    temperature_="null";
    std::istringstream stream(frame); std::string line;
    while (std::getline(stream,line)) {
      if (!StartsWith(line,"temperature\t")) continue;
      const auto value=ParseUnsigned(line.substr(line.rfind('\t')+1));
      if (value && *value>0 && *value<150000) temperature_=std::to_string(static_cast<double>(*value)/1000);
    }
    thermal_at_=Clock::now();
  }
  void ParseProcesses(const std::string &frame) {
    std::istringstream stream(frame); std::string line; double sample=0,ticks=100;
    std::unordered_map<std::string,Process> next;
    while (std::getline(stream,line)) {
      if (StartsWith(line,"sample\t")) { auto f=SplitWhitespace(line); if(f.size()>2) {sample=ParseDouble(f[1]).value_or(0);ticks=ParseDouble(f[2]).value_or(100);} continue; }
      if (!StartsWith(line,"process\t")) continue;
      std::vector<std::string> f; std::istringstream fields(line); std::string v;
      while(std::getline(fields,v,'\t')) f.push_back(v);
      if(f.size()!=8 || next.size()>=8192 || ticks<=0 || sample<=0) continue;
      Process p; p.pid=ParseUnsigned(f[1]).value_or(0);p.state=f[3];p.start=ParseUnsigned(f[4]).value_or(0);p.ticks=ParseUnsigned(f[5]).value_or(0);p.rss=ParseUnsigned(f[6]).value_or(0);p.name=f[7].substr(0,96);p.sample=sample;p.state_since=sample;
      if(!p.pid || !p.start || p.state.size()!=1 || std::string("RSDZTtXIWP").find(p.state)==std::string::npos) continue;
      const auto key=std::to_string(p.pid)+":"+std::to_string(p.start);
      auto old=previous_processes_.find(key);
      if(old!=previous_processes_.end() && sample>old->second.sample && sample-old->second.sample<=65 && p.ticks>=old->second.ticks) {
        p.cpu=100.0*static_cast<double>(p.ticks-old->second.ticks)/ticks/(sample-old->second.sample);
        p.growth=static_cast<double>(p.rss)-static_cast<double>(old->second.rss);
        if(p.state==old->second.state) p.state_since=old->second.state_since;
      }
      next[key]=p;
    }
    std::vector<const Process*> selected, all;
    for(const auto &entry:next) all.push_back(&entry.second);
    auto add=[&](const Process *p){ if(selected.size()<30 && std::find(selected.begin(),selected.end(),p)==selected.end()) selected.push_back(p); };
    for(const auto &sort: {0,1,2,3}) {
      std::sort(all.begin(),all.end(),[&](const Process *a,const Process *b){
        if(sort==0) return a->cpu==b->cpu ? a->pid<b->pid : a->cpu>b->cpu;
        if(sort==1) return a->rss==b->rss ? a->pid<b->pid : a->rss>b->rss;
        if(sort==2) return a->growth==b->growth ? a->pid<b->pid : a->growth>b->growth;
        return a->state_since==b->state_since ? a->pid<b->pid : a->state_since<b->state_since;
      });
      unsigned int count=0;
      for(const auto *p:all) {
        if(sort==2 && p->growth<=0) continue;
        if(sort==3 && p->state!="D" && p->state!="Z") continue;
        add(p); if(++count>=static_cast<unsigned int>(sort<2?10:5)) break;
      }
    }
    process_sample_=sample>0 ? std::to_string(sample) : "null";
    processes_truncated_=false;
    std::string out="[";bool first=true;
    for(const auto *p:selected) {
      std::ostringstream entry;
      entry<<"{\"pid\":"<<p->pid<<",\"start_ticks\":"<<p->start<<",\"name_bytes\":"<<JsonString(p->name)<<",\"state\":"<<JsonString(p->state)
         <<",\"cpu_pct_one_core\":"<<(p->cpu<0?"null":std::to_string(p->cpu))<<",\"rss_kib\":"<<p->rss
         <<",\"rss_delta_kib\":"<<(p->cpu<0?"null":std::to_string(p->growth))<<",\"state_observed_seconds\":"<<std::max(0.0,sample-p->state_since)<<'}';
      if(out.size()+entry.str().size()+2>10000) {processes_truncated_=true;break;}
      if(!first) out+=',';
      first=false;out+=entry.str();
    }
    out+=']';processes_=out;previous_processes_=std::move(next);
  }
};
