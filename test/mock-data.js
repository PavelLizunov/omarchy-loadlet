.pragma library

function populate(ctrl) {
  ctrl.cpuReady = true
  ctrl._processMetricsReady = true

  ctrl._snapshot = {
    schema: 1,
    sample: 270000,
    uptime: 270420,
    cpuFrequencyMHz: 3449,
    memorySpeedMTs: 5500,
    cpu: { total: 100000, busy: 24000 },
    topology: Array.from({length: 12}, function(_, id) {
      return {id: id, cls: id < 8 ? "performance" : "efficiency",
        domain: "package0", cluster: id < 8 ? "0" : "1",
        core: id < 8 ? Math.floor(id / 2) : id - 4,
        maxKhz: id < 8 ? 5200000 : 3800000}
    }),
    memory: {
      total: 34359738368,      // 32 GiB
      available: 19327352832,  // 18 GiB available -> 14 GiB used
      cached: 4831838208,      // 4.5 GiB cached
      swapTotal: 8589934592,   // 8 GiB
      swapFree: 6098853560     // 29% swap
    }
  }

  ctrl._thermalSnapshot = {
    schema: 1,
    sample: 270000,
    temperatures: [{ label: "Package id 0", kind: "cpu", value: 54.0 }]
  }

  ctrl._metrics = {
    cpu: 24.0,
    memory: 43.8,
    swap: 29.0,
    download: 3450000,
    upload: 420000,
    diskRead: 12582912,
    diskWrite: 4194304,
    cores: [48, 35, 62, 18, 12, 29, 14, 9, 31, 22, 15, 8].map(function(usage, id) {
      return {name: "cpu" + id, usage: usage}
    }),
    cpuHistory: [12, 18, 15, 28, 34, 22, 19, 25, 30, 24],
    memoryHistory: [41, 41, 42, 42, 43, 43, 43, 44, 44, 43.8],
    networkHistory: [500000, 1200000, 800000, 2400000, 4100000, 3450000],
    diskHistory: [1000000, 4000000, 2000000, 16000000, 12582912],
    diskDevices: [{ id: "nvme0n1", name: "nvme0n1", read: 12582912, write: 4194304 }],
    diskHistories: {nvme0n1: [1000000, 4000000, 12582912]}
  }

  ctrl._gpuSnapshot = { schema: 1, sample: 270000 }
  ctrl._gpus = [{
    id: "gpu0",
    name: "RTX 4070",
    usage: 18,
    frequencyMHz: 1920,
    memoryKind: "vram",
    memoryUsed: 2684354560,
    memoryTotal: 12884901888
  }]

  ctrl._storageSnapshot = {
    schema: 1,
    sample: 270000,
    volumes: [{
      path: "/",
      device: "/dev/nvme0n1p2",
      filesystem: "btrfs",
      total: 1024209543168,
      used: 412316860416,
      available: 611892682752
    }]
  }

  var now = Date.now()/1000
  var temperatures = [
    {id:'cpu-tctl',chip:'k10temp',label:'Tctl',category:'cpu',owner:'AMD Ryzen 9 7945HX3D',value:54,location:'package0'},
    {id:'gpu-temp',chip:'nvidia',label:'edge',category:'gpu',owner:'NVIDIA GeForce RTX 5060 Ti',value:48,location:'0000:01:00.0'},
    {id:'board-temp1',chip:'it8613',label:'temp1',category:'motherboard',owner:'ITE IT8613E',value:42,location:'isa0a30'}
  ]
  var fans = [{id:'fan2',chip:'it8613',label:'fan2',category:'motherboard',owner:'ITE IT8613E',unit:'rpm',value:700,location:'isa0a30'}]
  ctrl._sensorSnapshot = {schema:1,sample:270000,temperatures:temperatures,fans:fans,
    controls:[2,3,4,5].map(function(n){return {id:'pwm'+n,rpm:700+n*50,duty:40,mode:2}})}
  var history = {}
  temperatures.concat(fans).forEach(function(sensor){
    history[sensor.id] = Array.from({length:120},function(_,i){return {time:270000-(119-i)*3,wallTime:now-(119-i)*3,value:sensor.value+Math.sin(i/7)*3}})
  })
  ctrl.sensorHistory=history
  ctrl.sensorsUpdatedAt=Date.now()
  ctrl.freshnessClock=Date.now()

  ctrl._processes = [
    { pid: 41820, startTicks: 1000, name: "firefox", user: "demo", cpu: 18.4, rss: 2548039680, memory: 7.4, elapsed: 48210 },
    { pid: 30334, startTicks: 2000, name: "quickshell", user: "demo", cpu: 6.2, rss: 442499072, memory: 1.3, elapsed: 11240 },
    { pid: 19402, startTicks: 3000, name: "opencode", user: "demo", cpu: 4.8, rss: 612368384, memory: 1.8, elapsed: 7420 },
    { pid: 12844, startTicks: 4000, name: "code", user: "demo", cpu: 3.1, rss: 1583349760, memory: 4.6, elapsed: 36100 },
    { pid: 8821,  startTicks: 5000, name: "Hyprland", user: "demo", cpu: 2.5, rss: 318767104, memory: 0.9, elapsed: 270400 },
    { pid: 29104, startTicks: 6000, name: "ghostty", user: "demo", cpu: 1.4, rss: 214958080, memory: 0.6, elapsed: 19400 },
    { pid: 1892,  startTicks: 7000, name: "pipewire", user: "demo", cpu: 0.8, rss: 48234496, memory: 0.1, elapsed: 270400 },
    { pid: 44910, startTicks: 8000, name: "mpv", user: "demo", cpu: 0.5, rss: 164626432, memory: 0.5, elapsed: 1850 }
  ]
}
