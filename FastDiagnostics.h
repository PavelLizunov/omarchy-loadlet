// One native schedule inside the existing reader. Raw data never traverses QML.
class FastDiagnostics {
public:
  FastDiagnostics(Paths paths, ResourceCollector &resources, ProcessCollector &processes,
                  ThermalCollector &thermals, GpuCollector &gpus)
      : paths_(paths), resources_(resources), processes_(processes), thermals_(thermals), gpus_(gpus),
        journal_(paths, "diagnostics", 224*1024*1024, 24*60*60, 5),
        rollup_(paths, "diagnostics-rollup", 32*1024*1024, 7*24*60*60, 5) {}
  ~FastDiagnostics() { Stop(); }
  bool enabled() const { return journal_.enabled; }

  void Start(int interval) {
    if (interval != 250 && interval != 500 && interval != 1000) return;
    if (enabled() && interval_ == interval) return;
    Stop();
    interval_ = interval;gpu_interval_=2000;
    if (!journal_.Enable()) return;
    rollup_.Enable();
    session_ = std::to_string(std::chrono::duration_cast<std::chrono::microseconds>(
        std::chrono::system_clock::now().time_since_epoch()).count()) + "-" + std::to_string(getpid());
    sequence_ = 0; missed_ = 0; last_wall_ = last_boot_ = last_mono_ = 0;
    last_cpu_ = std::clock();
    next_ = Clock::now(); next_process_ = next_gpu_ = next_sensors_ = next_context_ = next_;
    next_rollup_ = next_ + std::chrono::seconds(10);
    rollup_started_=WallMs()/1000.0;low_time_=high_time_=0;
    cache_.clear(); low_ = 200; high_ = -200; count_ = 0; cpu_sum_ = 0; cpu_count_ = 0;
    Record("start", "\"interval_ms\":" + std::to_string(interval_) +
      ",\"process_interval_ms\":1000,\"gpu_interval_ms\":2000,\"sensor_interval_ms\":2000,"
      "\"limits\":\"sampled processes; source cadence may be slower; frequency is not proof of throttling\"", Clock::now());
  }
  void Stop() {
    if (enabled()) {
      SaveRollup();
      Record("stop", "\"reason\":\"requested_or_reader_exit\"", Clock::now());
    }
    journal_.Disable(); rollup_.Disable(); cache_.clear();
  }
  void Marker() { if (enabled()) { Record("marker", "\"label\":\"user_incident\"", Clock::now()); journal_.FlushPending(); } }
  void Flush() { journal_.FlushPending(); rollup_.FlushPending(); }
  int Timeout() const {
    if (!enabled()) return -1;
    const auto left = std::chrono::duration_cast<std::chrono::milliseconds>(next_ - Clock::now()).count();
    return static_cast<int>(std::max<std::int64_t>(0, std::min<std::int64_t>(1000, left + 1)));
  }
  void Status(std::ostream &out) const {
    out << "schema\tactivity-diagnostics\t2\nenabled\t" << enabled()
        << "\ninterval\t" << interval_ << "\nsession\t" << session_
        << "\ngpu-interval\t" << gpu_interval_
        << "\nsequence\t" << sequence_ << "\nmissed\t" << missed_
        << "\nduration-ms\t" << last_duration_ << "\nerror\t"
        << (journal_.error.empty() ? rollup_.error : journal_.error) << '\n';
  }
  bool Cached(const std::string &kind, std::ostream &out) const {
    if (!enabled()) return false;
    const auto it = cache_.find(kind);
    if (it == cache_.end()) return false;
    const int age = kind == "glance" || kind == "thermals" ? interval_*3 : 5000;
    if (Clock::now()-it->second.at > std::chrono::milliseconds(age)) return false;
    out << it->second.frame;
    return true;
  }
  void Tick() {
    if (!enabled() || Clock::now() < next_) return;
    const auto began = Clock::now();
    const auto lateness = std::max<std::int64_t>(0, std::chrono::duration_cast<std::chrono::milliseconds>(began-next_).count());
    missed_ += lateness / interval_;
    next_ += std::chrono::milliseconds((lateness/interval_+1)*interval_);
    const auto wall = WallMs(), mono = MonoMs(), boot = BootMs();
    if (last_wall_ && (std::llabs((wall-last_wall_)-(mono-last_mono_))>2000 ||
                       std::llabs((boot-last_boot_)-(mono-last_mono_))>2000 || mono-last_mono_>5000)) {
      Record("gap", "\"reason\":\"clock_suspend_or_collection_gap\"", began);
      journal_.previous_cpu_sample_=0; journal_.previous_processes_.clear(); cache_.clear();
    }
    last_wall_=wall; last_mono_=mono; last_boot_=boot;
    auto resource = Collect([&](std::ostream &out){ resources_.Glance(out); });
    auto thermal = Collect([&](std::ostream &out){ thermals_.Collect(out); });
    auto cpu_sensors = Collect([&](std::ostream &out){ thermals_.CollectSensors(out, true, true); });
    journal_.ParseResources(resource); journal_.ParseThermal(thermal);
    cache_["glance"]={resource, Clock::now()}; cache_["thermals"]={thermal, Clock::now()};
    Record("tick", "\"lateness_ms\":"+std::to_string(lateness)+",\"interval_ms\":"+std::to_string(interval_)+
      ",\"cpu_pct\":"+journal_.cpu_+",\"cpu_window_seconds\":"+journal_.cpu_window_+
      ",\"temperature_c\":"+journal_.temperature_+",\"memory\":"+journal_.memory_+
      ",\"sensors_tsv\":"+JsonString(cpu_sensors), began);
    auto temperature=ParseDouble(journal_.temperature_);
    if (temperature) {
      if(*temperature<low_) {low_=*temperature;low_time_=wall/1000.0;}
      if(*temperature>high_) {high_=*temperature;high_time_=wall/1000.0;}
      ++count_;
    }
    auto cpu=ParseDouble(journal_.cpu_);
    if (cpu) {cpu_sum_+=*cpu;++cpu_count_;}
    if (Due(next_process_, 1000)) {
      const auto at=Clock::now();
      auto frame=Collect([&](std::ostream &out){processes_.Collect(out);});
      if (StartsWith(frame,"error\t")) {
        journal_.previous_processes_.clear(); journal_.processes_="null";
      } else journal_.ParseProcesses(frame);
      cache_["processes"]={frame,Clock::now()};
      Record("processes", "\"process_sample_uptime\":"+journal_.process_sample_+
        ",\"processes\":"+journal_.processes_+",\"eligible_count\":"+std::to_string(journal_.previous_processes_.size())+
        ",\"selection\":\"top30_cpu_rss_growth_wait; not all processes\",\"collection_error\":"+
        JsonString(StartsWith(frame,"error\t") ? "capacity_or_read_error" : ""),at);
      const auto context_at=Clock::now();
      Record("pressure", Pressure(), context_at);
    }
    if (Due(next_gpu_, gpu_interval_)) {
      const auto at=Clock::now();
      auto frame=Collect([&](std::ostream &out){gpus_.Collect(out,false,true);});
      const auto duration=std::chrono::duration<double,std::milli>(Clock::now()-at).count();
      if (duration>20 && gpu_interval_<5000) {
        gpu_interval_=5000;next_gpu_=Clock::now()+std::chrono::milliseconds(gpu_interval_);
        Record("cadence", "\"source\":\"gpus\",\"interval_ms\":5000,\"reason\":\"slow_driver_query\"",at);
      }
      Record("gpus", "\"interval_ms\":"+std::to_string(gpu_interval_)+",\"gpu_tsv\":"+JsonString(frame),at);
      // Diagnostic GPU frames add columns; legacy consumers still own their wire format.
    }
    if (Due(next_sensors_, 2000)) {
      const auto at=Clock::now();
      auto frame=Collect([&](std::ostream &out){thermals_.CollectSensors(out, false, true);});
      Record("sensors", "\"sensors_tsv\":"+JsonString(frame),at);
    }
    if (Due(next_context_, 10000)) {
      const auto at=Clock::now();
      auto context=DiagnosticContext(paths_,16000);
      Record("context", "\"context\":"+(context.size()<=16000 ? context : "null")+
        ",\"collection_error\":"+JsonString(context.size()>16000 ? "context_capacity" : ""),at);
    }
    if (Due(next_rollup_,10000)) { SaveRollup(); rollup_.FlushPending(); }
    last_duration_=std::chrono::duration<double,std::milli>(Clock::now()-began).count();
  }
private:
  Paths paths_;
  ResourceCollector &resources_;
  ProcessCollector &processes_;
  ThermalCollector &thermals_;
  GpuCollector &gpus_;
  DiagnosticJournal journal_, rollup_;
  int interval_=500,gpu_interval_=2000;
  std::string session_;
  std::uint64_t sequence_=0,missed_=0;
  std::int64_t last_wall_=0,last_boot_=0,last_mono_=0;
  double last_duration_=0,low_=200,high_=-200,cpu_sum_=0;
  double rollup_started_=0,low_time_=0,high_time_=0;
  std::clock_t last_cpu_=0;
  unsigned int count_=0,cpu_count_=0;
  Clock::time_point next_{},next_process_{},next_gpu_{},next_sensors_{},next_context_{},next_rollup_{};
  struct Cache {std::string frame;Clock::time_point at;};
  std::unordered_map<std::string,Cache> cache_;
  static std::int64_t WallMs() { return std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::system_clock::now().time_since_epoch()).count(); }
  static std::int64_t MonoMs() { return std::chrono::duration_cast<std::chrono::milliseconds>(Clock::now().time_since_epoch()).count(); }
  static std::int64_t BootMs() { timespec t{};clock_gettime(CLOCK_BOOTTIME,&t);return t.tv_sec*1000LL+t.tv_nsec/1000000; }
  static bool Due(Clock::time_point &next, int ms) {
    const auto now=Clock::now();if(now<next)return false;
    const auto elapsed=std::chrono::duration_cast<std::chrono::milliseconds>(now-next).count();
    next+=std::chrono::milliseconds((elapsed/ms+1)*ms);return true;
  }
  template<class F> std::string Collect(F collect) {
    FrameBuffer frame;std::ostream out(&frame);input_overflow=false;collect(out);
    return frame.exceeded || input_overflow ? "error\tcapacity\n" : frame.data;
  }
  std::string Prefix(const std::string &type, Clock::time_point began) {
    const auto cpu_now=std::clock();
    const double cpu_ms=1000.0*(cpu_now-last_cpu_)/CLOCKS_PER_SEC;last_cpu_=cpu_now;
    const auto duration=std::chrono::duration<double,std::milli>(Clock::now()-began).count();
    return "{\"schema\":2,\"time\":"+std::to_string((WallMs()-duration)/1000.0)+
      ",\"mono_ms\":"+std::to_string(std::chrono::duration_cast<std::chrono::milliseconds>(began.time_since_epoch()).count())+
      ",\"duration_ms\":"+std::to_string(duration)+
      ",\"collector_cpu_ms_since_record\":"+std::to_string(cpu_ms)+
      ",\"boot_id\":"+JsonString(journal_.boot_)+",\"session\":"+JsonString(session_)+
      ",\"sequence\":"+std::to_string(++sequence_)+",\"type\":"+JsonString(type);
  }
  void Record(const std::string &type,const std::string &fields,Clock::time_point began) {
    auto row=Prefix(type,began)+","+fields+"}\n";
    if(row.size()>32768) row=Prefix("error",began)+",\"source\":"+JsonString(type)+",\"reason\":\"record_capacity\"}\n";
    journal_.AppendRecord(row);
  }
  void SaveRollup() {
    if (!count_ && !cpu_count_) return;
    rollup_.AppendRecord(Prefix("rollup",Clock::now())+",\"from\":"+std::to_string(rollup_started_)+
      ",\"temperature_min_time\":"+std::to_string(low_time_)+",\"temperature_max_time\":"+std::to_string(high_time_)+
      ",\"temperature_count\":"+std::to_string(count_)+
      ",\"temperature_min\":"+(count_?std::to_string(low_):"null")+
      ",\"temperature_max\":"+(count_?std::to_string(high_):"null")+
      ",\"cpu_count\":"+std::to_string(cpu_count_)+",\"cpu_mean\":"+(cpu_count_?std::to_string(cpu_sum_/cpu_count_):"null")+"}\n");
    low_=200;high_=-200;count_=cpu_count_=0;cpu_sum_=0;rollup_started_=WallMs()/1000.0;
  }
  std::string Pressure() const {
    std::string out="\"psi\":{";bool first=true;
    for(const auto &kind:{"cpu","memory","io"}) {
      if(!first)out+=',';
      first=false;auto value=ReadText(Join(paths_.proc,std::string("pressure/")+kind));
      out+=JsonString(kind)+":"+(value && value->size()<2048?JsonString(*value):"null");
    }
    out+="},\"vmstat\":{";first=true;
    auto raw=ReadText(Join(paths_.proc,"vmstat"));
    std::istringstream stream(raw.value_or(""));std::string key,value;
    while(stream>>key>>value) {
      if(key!="pswpin" && key!="pswpout" && key!="pgmajfault" && key!="oom_kill")continue;
      if(!first)out+=',';
      first=false;out+=JsonString(key)+":"+JsonNumber(ParseUnsigned(value));
    }
    return out+"}";
  }
};
