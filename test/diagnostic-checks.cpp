// Tests actual journal implementation with controlled counters and clock ages.
#define main activity_sampler_main
#include "../activity-sampler.cpp"
#undef main
#include <cassert>

namespace {
struct DiagnosticJournalChecks {
  static void Run(const std::string &base) {
    Paths paths{Join(base,"proc"),Join(base,"sys"),"","","","",""};
    DiagnosticJournal j(paths);
    assert(j.Enable());
    auto resources=[](int sample,int total,int idle){return "schema\tactivity-resources\t1\nsample\t"+std::to_string(sample)+"\ncpu\tcpu\t"+std::to_string(total)+"\t"+std::to_string(idle)+"\nmemory\t1000\t600\t200\t150\t100\n";};
    j.ParseResources(resources(100,10000,5000));assert(j.cpu_=="null");
    j.ParseResources(resources(115,11000,5700));assert(std::abs(std::stod(j.cpu_)-30)<1e-6);
    j.ParseResources(resources(130,12000,5700));assert(std::stod(j.cpu_)==100);
    j.ParseResources(resources(145,13000,6700));assert(std::stod(j.cpu_)==0);
    j.ParseResources(resources(200,14000,6800));assert(j.cpu_=="null");
    j.ParseResources(resources(199,14010,6801));assert(j.cpu_=="null");
    j.ParseResources(resources(214,14020,7000));assert(j.cpu_=="null");
    j.ParseResources(resources(229,100,50));assert(j.cpu_=="null");
    for(int idleDelta=0;idleDelta<=1000;idleDelta+=25) {
      j.previous_cpu_sample_=100;j.previous_total_=10000;j.previous_idle_=5000;
      j.ParseResources(resources(115,11000,5000+idleDelta));
      assert(std::abs(std::stod(j.cpu_)-(100.0-idleDelta/10.0))<1e-5);
    }
    j.ParseResources("schema\tactivity-resources\t1\nsample\t230\nmemory\t100\t200\t0\t0\t0\n");assert(j.memory_=="null");
    auto process=[](int sample,int start,int ticks,int rss,const std::string &state){return "schema\tactivity-processes\t1\nsample\t"+std::to_string(sample)+"\t100\nprocess\t42\tuser\t"+state+"\t"+std::to_string(start)+"\t"+std::to_string(ticks)+"\t"+std::to_string(rss)+"\tworker\n";};
    j.ParseProcesses(process(100,100,1000,1024,"D"));
    assert(j.processes_.find("\"cpu_pct_one_core\":null")!=std::string::npos);
    j.ParseProcesses(process(130,100,7000,2048,"D"));
    assert(j.processes_.find("\"cpu_pct_one_core\":200.000000")!=std::string::npos);
    assert(j.processes_.find("\"rss_delta_kib\":1024.000000")!=std::string::npos);
    assert(j.processes_.find("\"state_observed_seconds\":30")!=std::string::npos);
    j.ParseProcesses(process(160,200,8000,512,"D")); // Same PID, new start.
    assert(j.processes_.find("\"cpu_pct_one_core\":null")!=std::string::npos);
    assert(j.processes_.find("\"state_observed_seconds\":0")!=std::string::npos);
    j.ParseProcesses(process(300,200,9000,256,"D"));assert(j.processes_.find("\"cpu_pct_one_core\":null")!=std::string::npos);
    j.ParseProcesses(process(330,200,10000,128,"S"));assert(j.processes_.find("\"rss_delta_kib\":-128.000000")!=std::string::npos);
    j.ParseThermal("schema\tactivity-thermals\t1\nsample\t100\ntemperature\tcpu\tk10temp\tTctl\t85500\n");assert(std::stod(j.temperature_)==85.5);
    j.Context();j.Observe("processes",process(360,200,11000,128,"Z"));
    j.Observe("glance",resources(244,1100,350));
    j.Sample();auto bytes=j.buffer_.size();j.Sample();assert(j.buffer_.size()==bytes);
    j.Flush();assert(j.error.empty());
    const std::string sensor="schema\tactivity-sensors\t1\ntemperature\tcpu\tk10temp\tTctl\t54000\n";
    j.buffer_=std::string(131040,' ')+"\n";
    const auto file_size=j.file_size_;
    j.SaveSensors(sensor);
    assert(j.file_size_>file_size && j.buffer_.size()<32768 && j.error.empty());
    const auto sensor_bytes=j.buffer_.size();
    j.SaveSensors(sensor);assert(j.buffer_.size()==sensor_bytes);
    j.last_sensor_write_-=std::chrono::seconds(16);
    j.SaveSensors(sensor);assert(j.buffer_.size()==sensor_bytes*2);
    j.Flush();assert(j.error.empty());
    j.buffer_=std::string(131040,' ')+"\n";j.sample_at_={};
    j.Sample();assert(j.buffer_.size()<32768 && j.error.empty());
    j.Flush();assert(j.error.empty());
    // Force retention against actual private files, without sleeping or live data.
    const int old=openat(j.dir_,"samples-000000-old.jsonl",O_CREAT|O_EXCL|O_WRONLY,0600);assert(old>=0);close(old);
    timespec age[2]{{std::time(nullptr)-8*86400,0},{std::time(nullptr)-8*86400,0}};
    assert(utimensat(j.dir_,"samples-000000-old.jsonl",age,0)==0);
    assert(j.Prune(0));assert(faccessat(j.dir_,"samples-000000-old.jsonl",F_OK,0)!=0);
    for(int i=0;i<43;i++) {
      auto name="samples-"+std::to_string(std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::system_clock::now().time_since_epoch()).count())+"-"+std::to_string(i)+".jsonl";
      int fd=openat(j.dir_,name.c_str(),O_CREAT|O_EXCL|O_WRONLY,0600);assert(fd>=0);assert(ftruncate(fd,1024*1024)==0);close(fd);
    }
    assert(j.Prune(100));
    { // A fixed unsupported sink verifies partial/failed batches stay journal-local.
      if(j.file_>=0) close(j.file_);
      j.file_=open("/dev/full",O_WRONLY|O_CLOEXEC);
      j.buffer_="{}\n";j.Flush();assert(j.error=="journal_open_failed");
      close(j.file_);j.file_=-1;j.buffer_.clear();
    }
    // A pre-existing unsafe entry causes a journal-local failure, never a write
    // through a link nor a sampler failure.
    assert(symlinkat("/dev/null",j.dir_,"samples-unsafe.jsonl")==0);
    j.buffer_="{\"schema\":1}\n";j.Flush();assert(j.error=="journal_retention_failed");
    assert(unlinkat(j.dir_,"samples-unsafe.jsonl",0)==0);
    // Late/invalid collection must clear freshness, not keep prior payload.
    j.Observe("thermals","error\tcapacity\n");assert(j.thermal_at_==Clock::time_point{});
    j.Disable();assert(!j.enabled);
    assert(j.Enable());assert(j.previous_cpu_sample_==0);
    assert(j.cpu_window_=="null");assert(j.cpu_=="null");j.Disable();
    std::cout<<"PASS journal mathematics, PID reuse, monotonic sensor admission, buffer pressure, retention and reset\n";
  }
};
}
int main(int argc,char **argv) {
  if(argc!=2) return 64;
  DiagnosticJournalChecks::Run(argv[1]);
}
