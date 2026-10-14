// Verify production SVG geometry against the selected concepts, plus input bounds.
const fs = require('node:fs'), vm = require('node:vm'), assert = require('node:assert/strict');
const vector = {};
vm.runInNewContext(fs.readFileSync('ActivityIconSvg.js', 'utf8'), vector);
const shapes = {}, thermal = {};
vm.runInNewContext(fs.readFileSync('docs/design-drafts/SimpleVariants.js','utf8'),shapes);
vm.runInNewContext(fs.readFileSync('docs/design-drafts/ThermalVariants.js','utf8'),thermal);
assert.equal(vector.bodies.length,11);
assert.equal(vector.defaultShape,10);
for(let i=0;i<10;i++) assert.equal(vector.bodies[i],shapes.bodies[i].path);
const render = (cpu,ram,fresh=true,hot=false) => vector.svg(1,cpu,ram,fresh,hot,'#d8dee9','#2e3440','#ebcb8b');
assert.notEqual(render(30,44),render(85,44));
assert.notEqual(render(30,44),render(30,92));
assert.equal(render(-1,-1),render(0,0));
assert.equal(render(95,95,false),render(0,0,false));
assert.equal(render(200,200),render(100,100));
assert.notEqual(render(85,92,true,true),render(85,92));
assert.equal(vector.shapeIndex(99),10);
assert.ok(!vector.svg(1,30,44,true,false,'"><script>','bad','bad').includes('<script>'));
assert.ok(vector.svg(1,30,44,true,false,'#80d8dee9','#802e3440','#ebcb8b').includes('fill-opacity="0.5019607843137255"'));
const sized = (w,h) => vector.svg(1,30,44,true,0,'#d8dee9','#2e3440','#ebcb8b',undefined,undefined,w,h);
for (const [w,h,expected] of [[20,20,'20'],[20.01,20.01,'21'],[NaN,-1,'16'],[Infinity,Infinity,'16'],[5000,5000,'4096']]) {
  assert.ok(sized(w,h).includes('width="'+expected+'" height="'+expected+'" viewBox="0 0 16 16"'));
}
assert.equal(sized(20,20).replace('width="20" height="20"','width="16" height="16"'),render(30,44));
console.log('PASS production icon: selected geometry, gauges, stale values, heat, alpha, colors and Qt 6.12 data-URL dimensions');
for (const [v,wanted] of [[-1,'fg'],[NaN,'fg'],[0,'fg'],[64.99,'fg'],[65,'accent'],[84.99,'accent'],[85,'urgent']])
  assert.equal(vector.pressureColor(v,'fg','accent','urgent'),wanted);
const colored=vector.svg(1,70,92,true,true,'#d8dee9','#2e3440','#ebcb8b','#88c0d0','#ebcb8b');
assert.ok(colored.includes('stroke="#88c0d0"'));
assert.ok(colored.includes('fill="#ebcb8b"'));
assert.ok(colored.includes('translate(5.4 3.2)'));
assert.ok(colored.includes('stroke-width="2.4"'));
assert.ok(colored.includes('M5 10.3 Q8 10.9 11 10.3'));
assert.equal(new Set([10,30,60,90].map(n=>render(n,44))).size,4);
console.log('PASS pressure palette: shared 65/85 thresholds and independent CPU/RAM fill colors');
const heat={};vm.runInNewContext(fs.readFileSync('HeatPolicy.js','utf8'),heat);
assert.deepEqual([1,2,3,4].map(n=>heat.interval(n)),[15000,10000,5000,3000]);
let level=0;
for(const [temperature,expected] of [[80,1],[85,2],[90,3],[95,4],[94,4],[92,3],[87,2],[82,1],[76,1],[74,0]]) {
  level=heat.nextLevel(level,temperature,80,true);assert.equal(level,expected);
}
assert.equal(heat.nextLevel(4,95,80,false),0);
assert.equal(heat.nextLevel(0,85,85,true),1);
assert.equal(heat.nextLevel(4,89,80,true),3,'multi-level cooling must retain the lower hysteresis band');
assert.equal(heat.nextLevel(4,84,80,true),2);
for(let threshold=60;threshold<=110;threshold+=5) {
  for(let temp=50;temp<145;temp+=0.25) {
    for(let before=0;before<=4;before++) {
      const after=heat.nextLevel(before,temp,threshold,true);
      assert.ok(after>=0 && after<=4);
      if(temp<threshold-5) assert.equal(after,0);
      if(before===0 && temp<threshold) assert.equal(after,0);
      if(before>1 && temp>=threshold+(before-1)*5-2 && temp<threshold+(before-1)*5) assert.equal(after,before);
    }
  }
}
assert.equal(new Set([1,2,3,4].map(n=>vector.svg(1,90,92,true,n,'#d8dee9','#2e3440','#ebcb8b'))).size,4);
console.log('PASS heat levels: four shapes, 15/10/5/3 cadence, cooling deadband, custom threshold and stale cancellation');
const draft={};vm.runInNewContext(fs.readFileSync('docs/design-drafts/OmarchyVariants.js','utf8'),draft);
const split=(cpu,ram,fresh=true,severity=0,fg='#d8dee9')=>vector.svg(10,cpu,ram,fresh,severity,fg,'#2e3440','#ebcb8b',
  vector.pressureColor(fresh?cpu:-1,fg,'#81a1c1','#ebcb8b'),vector.pressureColor(fresh?ram:-1,fg,'#81a1c1','#ebcb8b'),32,32,'#81a1c1');
const groups=s=>s.match(/<g id="(?:cpu|ram)-cells">.*?<\/g>/g);
const symmetricContour='M3 2H13V3H14V4H15V6H14V7H15V9H14V10H15V12H14V13H13V14H3V13H2V12H1V10H2V9H1V7H2V6H1V4H2V3H3Z';
const faceHoles='M4 4V10H7V4Z M9 4V10H12V4Z M3 11V12H5V11Z M11 11V12H13V11Z';
const actualContour=vector.bodies[10].split('Z ')[0]+'Z';
const points=[];let x=0,y=0;
for(const m of actualContour.matchAll(/([MHVZ])(\d+)?(?: (\d+))?/g)) {
  if(m[1]==='M') {x=Number(m[2]);y=Number(m[3]);}
  else if(m[1]==='H') x=Number(m[2]);
  else if(m[1]==='V') y=Number(m[2]);
  else continue;
  points.push([x,y]);
}
const outer=new Set(),occupied=new Set();
for(let py=0;py<16;py++)for(let px=0;px<16;px++) {
  let inside=false;
  for(let i=0;i<points.length;i++) {
    const a=points[i],b=points[(i+1)%points.length];
    assert.ok(a[0]===b[0]||a[1]===b[1],'edge is orthogonal');
    if((a[1]>py+.5)!==(b[1]>py+.5) && px+.5<(b[0]-a[0])*(py+.5-a[1])/(b[1]-a[1])+a[0]) inside=!inside;
  }
  const hole=((px>=4&&px<7)||(px>=9&&px<12))&&py>=4&&py<10
    || ((px>=3&&px<5)||(px>=11&&px<13))&&py===11;
  if(inside) outer.add(px+16*py);
  if(inside&&!hole) occupied.add(px+16*py);
}
for(let py=0;py<16;py++)for(let px=0;px<16;px++) {
  assert.equal(outer.has(px+16*py),outer.has(15-px+16*py),'outer silhouette must mirror left/right');
  assert.equal(outer.has(px+16*py),outer.has(px+16*(15-py)),'outer shoulders/base must mirror top/bottom');
  assert.equal(occupied.has(px+16*py),occupied.has(15-px+16*py),'quiet face must mirror left/right');
}
assert.equal(vector.bodies[10],symmetricContour+' '+faceHoles,'paired notches and original face holes');
assert.equal(occupied.size,112,'balanced body retains connected optical weight');
const seen=new Set(),pending=[occupied.values().next().value];
while(pending.length) {
  const point=pending.pop();if(seen.has(point))continue;seen.add(point);
  for(const next of [point-1,point+1,point-16,point+16])if(occupied.has(next)&&!seen.has(next))pending.push(next);
}
assert.equal(seen.size,occupied.size,'body remains one connected foreground component');
assert.deepEqual([Math.min(...points.map(p=>p[0])),Math.min(...points.map(p=>p[1])),Math.max(...points.map(p=>p[0])),Math.max(...points.map(p=>p[1]))],[1,2,15,14],'14-unit width, unchanged 12-unit height and centered canvas');
for(const fresh of [true,false])for(const cpu of [-1,NaN,0,10,16,17,30,50,65,85,100,200])for(const ram of [0,20,44,70,92,100]) {
  const actual=split(cpu,ram,fresh), accepted=draft.svg(5,cpu,ram,fresh,false,'#d8dee9','#88c0d0','#ebcb8b',32,32,1,2);
  assert.equal(actual.match(/fill-rule="evenodd" d="([^"]+)"/)[1].split('Z ').slice(1).join('Z '),
    accepted.match(/fill-rule="evenodd" d="([^"]+)"/)[1].split('Z ').slice(1).join('Z '),'selected eyes and cheeks unchanged');
  const geometry=s=>groups(s).map(g=>g.replace(/fill="#[0-9a-f]{6}"/gi,'fill="palette"'));
  assert.deepEqual(geometry(actual),geometry(accepted),'accepted six-row eye geometry/quantization parity');
}
for(const n of [0,10,16,17,34,50,67,84,100]) {
  const cells=groups(split(n,0))[0];
  assert.equal((cells.match(/opacity="1"/g)||[]).length,Math.floor(n*6/100));
}
assert.equal(new Set([0,1,2,3,4].map(n=>split(85,92,true,n))).size,5);
assert.equal(split(100,100,false),split(0,0,false));
assert.ok(split(30,44,true,4,'#80d8dee9').includes('fill-opacity="0.5019607843137255"'));
assert.ok(split(30,44,true,0,'"><script>').indexOf('<script>')<0);
console.log('PASS symmetric Split die: mirrored body/quiet face, connected14x12 silhouette, original eyes/cheeks/rows, independent axes, heat and alpha');
// A filled row painted like the solid body erases the gauge at low load.
const rgb=s=>[1,3,5].map(i=>parseInt(s.slice(i,i+2),16)/255);
const luminance=s=>rgb(s).map(v=>v<=0.04045?v/12.92:((v+0.055)/1.055)**2.4).reduce((sum,v,i)=>sum+v*[0.2126,0.7152,0.0722][i],0);
const contrast=(a,b)=>{const lo=Math.min(luminance(a),luminance(b)),hi=Math.max(luminance(a),luminance(b));return (hi+0.05)/(lo+0.05);};
for(const [fg,bg,accent,urgent] of [['#d8dee9','#2e3440','#81a1c1','#bf616a'],['#202020','#f4f4f4','#0067c0','#cc2222'],['#d8dee9','#2e3440','#d8dee9','#d8dee9']]) {
  for(const [cpu,ram] of [[19,55],[64,70],[85,100]]) {
    const s=vector.svg(10,cpu,ram,true,0,fg,bg,urgent,vector.pressureColor(cpu,fg,accent,urgent),vector.pressureColor(ram,fg,accent,urgent),32,32,accent);
    for(const g of groups(s))for(const m of g.matchAll(/fill="(#[0-9a-f]{6})" opacity="1"/gi)) {
      assert.notEqual(m[1],fg,'filled eye row must not merge with the body');
      assert.ok(contrast(m[1],fg)>=3,'active-row/body contrast must be at least 3 for the checked opaque palette');
    }
  }
}
const activePaints=s=>groups(s).flatMap(g=>[...g.matchAll(/fill="(#[0-9a-f]{6})" opacity="1"/gi)].map(m=>m[1]));
const saturation=s=>{const values=rgb(s),hi=Math.max(...values),lo=Math.min(...values);return hi>0?(hi-lo)/hi:0;};
const vivid=activePaints(split(55,70));
assert.ok(vivid.every(c=>saturation(c)>=0.88),'normal and elevated filled rows must be saturated, not background/grey');
assert.notEqual(vivid[0],'#2e3440');
assert.ok(luminance(vivid[0])>luminance('#2e3440'),'normal fill is brighter than the prior background paint');
assert.notEqual(vivid[0],vivid.at(-1),'65 percent is brighter on the observed Nord palette');
const bounded=activePaints(vector.svg(10,55,70,true,0,'#d8dee9','#2e3440','#ebcb8b','#d8dee9','#88c0d0',32,32,'#88c0d0'));
assert.ok(luminance(bounded.at(-1))>=luminance(bounded[0]),'contrast may limit both brightness states to the same shade');
assert.ok(activePaints(split(85,92)).every(c=>saturation(c)>=0.88),'urgent fill retains saturated warning hue');
const themed=accent=>vector.svg(10,55,55,true,0,'#d8dee9','#2e3440','#bf616a','#d8dee9','#d8dee9',32,32,accent);
const blue=activePaints(themed('#81a1c1'))[0],green=activePaints(themed('#99cc99'))[0];
assert.ok(rgb(blue)[2]>rgb(blue)[0],'normal fill follows the actual theme accent hue');
assert.ok(rgb(green)[1]>rgb(green)[0] && rgb(green)[1]>rgb(green)[2],'alternate accent is not hardcoded blue');
assert.ok(saturation(activePaints(themed('#808080'))[0])>=0.88,'neutral accent uses a saturated fallback');
assert.equal(render(55,55),vector.svg(1,55,55,true,false,'#d8dee9','#2e3440','#ebcb8b',undefined,undefined,undefined,undefined,'#99cc99'),'legacy shapes ignore vivid palette input');
console.log('PASS vivid filled-row palette: saturated theme hues, brighter normal fill, body/active >=3, geometry unchanged');
for(const [value,wanted] of [[undefined,50],[null,50],['',50],[' ',50],[true,50],['60',60],[-1,0],[101,100],[49.6,50],[NaN,50],[Infinity,50]])
  assert.equal(vector.loadThreshold(value),wanted);
for(const [value,fresh,threshold,wanted] of [[49.99,true,50,0],[50,true,50,50],[55,true,50,55],[100,true,50,100],[150,true,50,100],[10,true,0,10],[99,true,100,0],[100,true,100,100],[-1,true,50,-1],[NaN,true,50,-1],[Infinity,true,50,-1],['80',true,50,-1],[90,false,50,-1]])
  assert.equal(vector.gaugeValue(value,fresh,threshold),wanted);
const gated=(cpu,ram,threshold)=>split(vector.gaugeValue(cpu,true,threshold),vector.gaugeValue(ram,true,threshold));
assert.equal(gated(19,49,50),split(0,0));
assert.equal(gated(50,55,50),split(50,55),'boundary uses actual load, never rescales the remaining range');
assert.equal(gated(19,55,0),split(19,55));
const thermalMarker=s=>s.match(/<path d="[^"]+" fill="#bf616a" opacity="1"\/>/)[0];
assert.equal(thermalMarker(vector.svg(10,19,55,true,4,'#d8dee9','#2e3440','#bf616a')),
  thermalMarker(vector.svg(10,0,0,true,4,'#d8dee9','#2e3440','#bf616a')), 'gauge suppression does not alter thermal markers');
console.log('PASS icon threshold: default50, inclusive boundary, no rescale, off0, clamp, stale/invalid and heat independence');
