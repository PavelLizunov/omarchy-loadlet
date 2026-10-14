// Original concepts inspired by the stepped, heavy Omarchy wordmark.
// Drafts only: not wired to production settings or telemetry.
var names = ["Block O", "Twin arches", "Stepped A", "Pixel chip", "Square face", "Split die"];
var bodies = [
  "M4 2H12V3H13V4H14V12H13V13H12V14H4V13H3V12H2V4H3V3H4Z M5 5V11H11V5Z",
  "M2 5H3V3H6V2H10V3H13V5H14V14H11V6H9V14H7V6H5V14H2Z",
  "M4 2H12V3H13V4H14V14H11V10H5V14H2V4H3V3H4Z M5 5V7H11V5Z",
  "M4 3H12V4H13V12H12V13H4V12H3V4H4Z M5 5V11H11V5Z",
  "M4 2H12V3H13V4H14V12H13V13H12V14H4V13H3V12H2V4H3V3H4Z M4 4V12H12V4Z",
  "M4 2H12V3H13V4H14V12H13V13H12V14H4V13H3V12H2V4H3V3H4Z M5 4V12H7V4Z M9 4V12H11V4Z"
];

var fillNames = ["Original", "A. Eight steps", "B. Four blocks", "C. Pixel weave"];
var faceNames = ["Original eyes", "1. Wider eyes", "2. Cheek dots", "3. C / R marks"];

function faceIndex(value) {
  return typeof value==='number' && isFinite(value) && Math.floor(value)===value && value>=0 && value<faceNames.length ? value : 0;
}

function fillIndex(value) {
  return typeof value==='number' && isFinite(value) && Math.floor(value)===value && value>=0 && value<fillNames.length ? value : 0;
}

function svg(variant, cpu, ram, fresh, hot, foreground, accent, urgent, width, height, fillStyle, faceStyle) {
  var index = Number(variant);
  index = isFinite(index) && Math.floor(index)===index && index>=0 && index<names.length ? index : 0;
  function ink(value, fallback) { return /^#[0-9a-f]{6}$/i.test(String(value)) ? String(value) : fallback; }
  var fg=ink(foreground,"#d8dee9"), ac=ink(accent,"#88c0d0"), heat=ink(urgent,"#bf616a");
  function level(value) { return fresh && typeof value==='number' && isFinite(value) && value>=0 ? Math.min(100,value)/100 : 0; }
  var c=level(cpu),r=level(ram), face=index===5?faceIndex(faceStyle):0;
  var sx=face>0?4:5, sw=face>0?3:2, sh=face===2?6:(face===3?4:8);
  var body=bodies[index];
  function hole(x,y,w,h) {return ' M'+x+' '+y+'V'+(y+h)+'H'+(x+w)+'V'+y+'Z';}
  if(face>0) {
    body=body.split(' M')[0]+hole(sx,4,sw,sh)+hole(9,4,sw,sh);
    // Cutout cheeks use the existing silhouette/foreground, not alert colors.
    if(face===2) body+=hole(3,11,2,1)+hole(11,11,2,1);
    if(face===3) {
      // A 3x3 R resembled A. Four rows distinguish its bowl/leg, but halve
      // gauge height. This remains an experimental native-size text treatment.
      var letters=[['111','100','100','111'],['110','101','110','101']];
      for(var axis=0;axis<2;axis++)for(var row=0;row<4;row++)for(var col=0;col<3;col++)
        if(letters[axis][row][col]==='1')body+=hole((axis===0?4:9)+col,9+row,1,1);
    }
  }
  function color(value) { return !fresh || !isFinite(value) || value<65 ? fg : (value<85 ? ac : heat); }
  function rect(x,y,w,h,fill,opacity) {
    return w>0 && h>0 ? '<rect x="'+x+'" y="'+y+'" width="'+w+'" height="'+h+'" fill="'+fill+'" opacity="'+opacity+'"/>' : '';
  }
  // CPU: horizontal rail. RAM: vertical rail. Keep 1-unit gaps between axes.
  var cx=index===1?2:(index===2?5:5), cy=index===1?15:(index===2?8:9);
  var cw=index===1?5:6, ch=index===2?1:2;
  var rx=index===1?9:(index===5?9:9),ry=index===1?15:(index===2?11:5);
  var rw=index===1?5:2,rh=index===1?1:(index===2?3:3);
  if(index===5) {cx=5;cy=9;cw=2;ch=3;rx=9;ry=4;rw=2;rh=8;}
  var pins=index===3 ? rect(5,1,2,2,fg,1)+rect(9,1,2,2,fg,1)+rect(1,5,2,2,fg,1)+rect(13,9,2,2,fg,1)+rect(5,13,2,2,fg,1)+rect(9,13,2,2,fg,1) : '';
  var eye=index===0||index===3||index===4 ? rect(5,5,2,2,fg,1) : '';
  var tracks=rect(cx,cy,cw,ch,fg,0.28)+rect(rx,ry,rw,rh,fg,0.28);
  var gauges=rect(cx,cy,cw*c,ch,color(cpu),1)+rect(rx,ry+rh*(1-r),rw,rh*r,color(ram),1);
  if(index===5) gauges=rect(sx,4+sh*(1-c),sw,sh*c,color(cpu),1)+rect(9,4+sh*(1-r),sw,sh*r,color(ram),1);
  if(index===5) tracks=rect(sx,4,sw,sh,fg,0.28)+rect(9,4,sw,sh,fg,0.28);
  var style=fillIndex(fillStyle);
  if(index===5 && style>0) {
    // Quantize down: filled cells never claim more load than the sample.
    // Integer geometry keeps the selected silhouette's tiny eyes on its grid.
    function cells(x,value,fill,axis) {
      var count=style===1?sh:(style===2?Math.ceil(sh/2):sw*sh), active=Math.floor(value*count);
      var out='<g id="'+axis+'-cells">';
      for(var n=0;n<count;n++) {
        var row=style===3 ? (n%sh) : n;
        var column=style===3 ? (Math.floor(n/sh)+row)%sw : 0;
        var y=style===2 ? 3+sh-row*2 : 3+sh-row;
        out+=rect(x+column,y,style===3?1:sw,1,n<active?fill:fg,n<active?1:0.28);
      }
      return out+'</g>';
    }
    tracks='';
    gauges=cells(sx,c,color(cpu),'cpu')+cells(9,r,color(ram),'ram');
  }
  var alert=hot ? '<path d="M5 2V1H6V0H7V1H8V3H6V2Z M10 3V1H11V0H12V1H13V2H12V3Z" fill="'+heat+'"/>' : '';
  function pixels(n) {return typeof n==='number'&&isFinite(n)&&n>0?Math.max(1,Math.min(4096,Math.ceil(n))):16;}
  return '<svg xmlns="http://www.w3.org/2000/svg" width="'+pixels(width)+'" height="'+pixels(height)+'" viewBox="0 0 16 16">'
    +pins+'<path fill="'+fg+'" fill-rule="evenodd" d="'+body+'"/>'+eye+tracks+gauges+alert+'</svg>';
}
