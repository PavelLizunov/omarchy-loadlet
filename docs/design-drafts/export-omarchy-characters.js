// Run from the repository root. Creates only missing task-owned SVG snapshots.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const vector={};vm.runInNewContext(fs.readFileSync(path.join(__dirname,'OmarchyVariants.js'),'utf8'),vector);
assert.equal(vector.names.length,6);
const render=(i,cpu=30,ram=44,fresh=true,hot=false,w=16,h=16)=>vector.svg(i,cpu,ram,fresh,hot,'#d8dee9','#88c0d0','#bf616a',w,h);
assert.equal(new Set(vector.names.map((_,i)=>render(i))).size,6);
for(let i=0;i<6;i++) {
  const normal=render(i);
  assert.notEqual(normal,render(i,85,44));
  assert.notEqual(normal,render(i,30,92));
  assert.notEqual(normal,render(i,30,44,true,true));
  assert.equal(render(i,85,92,false),render(i,0,0,false));
  assert.equal(render(i,NaN,-1),render(i,0,0));
  assert.equal(render(i,200,200),render(i,100,100));
  assert.ok(render(i,30,44,true,false,80,80).includes('width="80" height="80" viewBox="0 0 16 16"'));
  for(const state of ['normal','hot']) {
    const svg=state==='normal'?normal:render(i,85,92,true,true);
    const filename=path.join(__dirname,`omarchy-character-${String(i+1).padStart(2,'0')}-${state}.svg`);
    if(fs.existsSync(filename))assert.equal(fs.readFileSync(filename,'utf8'),svg);
    else fs.writeFileSync(filename,svg,{flag:'wx'});
  }
}
assert.ok(!vector.svg(0,30,44,true,false,'"><script>','bad','bad').includes('<script>'));
console.log('PASS six original Omarchy-style concepts: independent CPU/RAM, stale/invalid bounds, heat, raster dimensions and 12 snapshot identities');

const split=(style,cpu=30,ram=44,fresh=true,hot=false,w=16,h=16)=>vector.svg(5,cpu,ram,fresh,hot,'#d8dee9','#88c0d0','#bf616a',w,h,style);
assert.equal(new Set([0,1,2,3].map(style=>split(style))).size,4);
for(const bad of [-1,4,NaN,Infinity,'1',null])assert.equal(split(bad),split(0));
for(let style=1;style<=3;style++) {
  const count=style===1?8:(style===2?4:16);
  const cells=(svg,axis)=>svg.match(new RegExp('<g id="'+axis+'-cells">(.*?)</g>'))[1];
  for(let value=0;value<=100;value++) {
    const svg=split(style,value,44);
    const cpuCells=cells(svg,'cpu'),ramCells=cells(svg,'ram');
    assert.equal((cpuCells.match(/opacity="1"/g)||[]).length,Math.floor(value/100*count));
    assert.equal((cpuCells.match(/<rect /g)||[]).length,count);
    assert.equal(ramCells,cells(split(style,0,44),'ram'),'CPU must not alter RAM cells');
    for(const rect of svg.matchAll(/<rect x="([^"]+)" y="([^"]+)" width="([^"]+)" height="([^"]+)"/g)) {
      const [x,y,w,h]=rect.slice(1).map(Number);
      assert.ok([x,y,w,h].every(Number.isInteger),'pixel treatments must stay on integer geometry');
      assert.ok(y>=4 && y+h<=12 && ((x>=5 && x+w<=7)||(x>=9 && x+w<=11)));
    }
  }
  assert.equal(cells(split(style,30,44),'cpu'),cells(split(style,30,92),'cpu'));
  assert.equal(split(style,85,92,false),split(style,0,0,false));
  assert.equal(split(style,NaN,-1),split(style,0,0));
  assert.equal(split(style,200,200),split(style,100,100));
  assert.notEqual(split(style,85,92),split(style,85,92,true,true));
  assert.ok(split(style,30,44,true,false,32,32).includes('width="32" height="32"'));
  assert.ok(split(style).includes('d="'+vector.bodies[5]+'"'),'selected silhouette must remain unchanged');
  for(const state of ['normal','hot']) {
    const svg=state==='normal'?split(style):split(style,85,92,true,true);
    const filename=path.join(__dirname,`omarchy-split-fill-${String.fromCharCode(96+style)}-${state}.svg`);
    if(fs.existsSync(filename))assert.equal(fs.readFileSync(filename,'utf8'),svg);
    else fs.writeFileSync(filename,svg,{flag:'wx'});
  }
}
console.log('PASS Split die fills A/B/C: 303 monotone cell-count checks, unchanged silhouette, integer bounds, independent gauges, stale/invalid data and six snapshot identities');

const faceSvg=(face,style=2,cpu=30,ram=44,fresh=true,hot=false,w=16,h=16)=>vector.svg(5,cpu,ram,fresh,hot,'#d8dee9','#88c0d0','#bf616a',w,h,style,face);
for(const bad of [-1,4,NaN,Infinity,'1',null])assert.equal(faceSvg(bad),faceSvg(0));
assert.equal(new Set([0,1,2,3].map(face=>faceSvg(face))).size,4);
for(let face=1;face<=3;face++) {
  const height=face===1?8:(face===2?6:4);
  for(let style=1;style<=3;style++) {
    const count=style===1?height:(style===2?Math.ceil(height/2):3*height);
    const cells=(svg,axis)=>svg.match(new RegExp('<g id="'+axis+'-cells">(.*?)</g>'))[1];
    for(let value=0;value<=100;value++) {
      const svg=faceSvg(face,style,value,44),cpu=cells(svg,'cpu'),ram=cells(svg,'ram');
      assert.equal((cpu.match(/opacity="1"/g)||[]).length,Math.floor(value/100*count));
      assert.equal((cpu.match(/<rect /g)||[]).length,count);
      assert.equal(ram,cells(faceSvg(face,style,0,44),'ram'));
      for(const rect of svg.matchAll(/<rect x="([^"]+)" y="([^"]+)" width="([^"]+)" height="([^"]+)"/g)) {
        const [x,y,w,h]=rect.slice(1).map(Number);
        assert.ok([x,y,w,h].every(Number.isInteger));
        assert.ok(y>=4 && y+h<=4+height && ((x>=4 && x+w<=7)||(x>=9 && x+w<=12)));
      }
      assert.equal(svg.match(/<path fill="[^"]+" fill-rule="evenodd" d="([^"]+)"/)[1].split(' M')[0],vector.bodies[5].split(' M')[0]);
    }
    assert.equal(cells(faceSvg(face,style,30,44),'cpu'),cells(faceSvg(face,style,30,92),'cpu'));
    assert.equal(faceSvg(face,style,85,92,false),faceSvg(face,style,0,0,false));
    assert.equal(faceSvg(face,style,NaN,-1),faceSvg(face,style,0,0));
    assert.equal(faceSvg(face,style,200,200),faceSvg(face,style,100,100));
    assert.notEqual(faceSvg(face,style,85,92),faceSvg(face,style,85,92,true,true));
    assert.ok(faceSvg(face,style,30,44,true,false,32,32).includes('width="32" height="32"'));
  }
  for(const state of ['normal','hot']) {
    const svg=state==='normal'?faceSvg(face):faceSvg(face,2,85,92,true,true);
    const filename=path.join(__dirname,`omarchy-split-face-${face}-${state}.svg`);
    if(fs.existsSync(filename))assert.equal(fs.readFileSync(filename,'utf8'),svg);
    else fs.writeFileSync(filename,svg,{flag:'wx'});
  }
}
assert.ok(faceSvg(2).includes(' M3 11V12H5V11Z M11 11V12H13V11Z'));
console.log('PASS wider-eye/cheek/C-R drafts: 909 cell-count and integer-bound cases, same outer silhouette, independent gauges, invalid/stale values and six new snapshots');
