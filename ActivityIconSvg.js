// Legacy silhouettes plus the selected Omarchy-style Split die.
var defaultShape = 10;
var bodies = [
  "M5 3 Q3 3 3 5 L3 11 Q3 13 5 13 L11 13 Q13 13 13 11 L13 5 Q13 3 11 3 Z",
  "M5 3.4 L10.8 2.8 Q12.5 2.6 12.7 4.8 L13.2 10.6 Q13.4 12.4 11.2 12.7 L5.2 13.3 Q3.5 13.4 3.3 11.3 L2.8 5.4 Q2.7 3.6 5 3.4 Z",
  "M3.1 6.6 C3 3.2 5.7 2.4 8.5 2.7 C12 2.6 13.5 5.1 13.1 8.7 C13 12 10.7 13.5 7.3 13.1 C3.9 13 2.7 10.6 3.1 6.6 Z",
  "M6 2.8 C9 1.8 12.9 3.5 13 7.2 C13.6 11.5 10.8 13.4 7.6 13 C4.3 13.3 2.2 11.2 3.5 8.7 C4.5 7 2.6 4 6 2.8 Z",
  "M3.7 6 Q3.7 2.4 8 2.4 Q12.3 2.4 12.3 6 L12.3 10 Q12.3 13.6 8 13.6 Q3.7 13.6 3.7 10 Z",
  "M6 3.8 L10 3.8 Q13.8 3.8 13.8 8 Q13.8 12.2 10 12.2 L6 12.2 Q2.2 12.2 2.2 8 Q2.2 3.8 6 3.8 Z",
  "M3 7 Q3 2.7 8 2.7 Q13 2.7 13 7 L13 12.6 Q11.4 13.6 10 12.2 Q8 14 6 12.2 Q4.4 13.7 3 12.6 Z",
  "M3.3 7.7 Q3.3 2.7 8 2.7 Q12.7 2.7 12.7 7.7 L12.7 11.3 Q12.7 13 11 13 L5 13 Q3.3 13 3.3 11.3 Z",
  "M6.2 3 Q8 1.8 9.4 3.2 L13 9.5 Q14.4 12.5 11.4 12.8 L4.4 13 Q1.8 12.8 3 10 Z",
  "M13.2 8 A5.2 5.2 0 1 1 2.8 8 A5.2 5.2 0 1 1 13.2 8 Z",
  "M3 2H13V3H14V4H15V6H14V7H15V9H14V10H15V12H14V13H13V14H3V13H2V12H1V10H2V9H1V7H2V6H1V4H2V3H3Z M4 4V10H7V4Z M9 4V10H12V4Z M3 11V12H5V11Z M11 11V12H13V11Z"
];

function shapeIndex(value) {
  var n = Number(value);
  return isFinite(n) && n >= 0 && n < bodies.length && Math.floor(n) === n ? n : defaultShape;
}

function loadThreshold(value) {
  if (typeof value !== "number" && !(typeof value === "string" && value.trim() !== "")) return 50;
  var n = Number(value);
  return isFinite(n) ? Math.max(0, Math.min(100, Math.round(n))) : 50;
}

// Visual suppression only; source readings and the percentage scale stay intact.
function gaugeValue(value, fresh, threshold) {
  if (!fresh || typeof value !== "number" || !isFinite(value) || value < 0) return -1;
  var n = Math.min(100, value);
  return n < loadThreshold(threshold) ? 0 : n;
}

function pressureColor(value, foreground, accent, urgent) {
  return typeof value === "number" && isFinite(value) && value >= 0
    ? (value >= 85 ? urgent : (value >= 65 ? accent : foreground)) : foreground;
}

function svg(shape, cpu, ram, fresh, hot, foreground, background, heatColor, cpuColor, ramColor, pixelWidth, pixelHeight, accentColor) {
  shape = shapeIndex(shape);
  function paint(value, fallback) {
    // QColor strings are #rrggbb or #aarrggbb. Preserve host alpha separately.
    var s = String(value);
    if (/^#[0-9a-f]{8}$/i.test(s))
      return {color: "#" + s.slice(3), alpha: parseInt(s.slice(1, 3), 16) / 255};
    return {color: /^#[0-9a-f]{6}$/i.test(s) ? s : fallback, alpha: 1};
  }
  function level(value) {
    return fresh && typeof value === "number" && isFinite(value) && value >= 0
      ? Math.min(100, value) / 100 : 0;
  }
  var ink = paint(foreground, "#d8dee9"), paper = paint(background, "#2e3440");
  var heat = paint(heatColor, "#ebcb8b");
  var cpuInk = paint(cpuColor === undefined ? foreground : cpuColor, ink.color);
  var ramInk = paint(ramColor === undefined ? foreground : ramColor, ink.color);
  var c = level(cpu), r = level(ram), wide = shape === 5, wedge = shape === 8;
  var severity = hot === true ? 1 : Math.max(0,Math.min(4,Number(hot)||0));
  // Qt 6.12 inline SVG decoding also needs explicit raster dimensions.
  function pixels(value) {
    return typeof value === "number" && isFinite(value) && value > 0
      ? Math.max(1, Math.min(4096, Math.ceil(value))) : 16;
  }
  var svgStart = '<svg xmlns="http://www.w3.org/2000/svg" width="' + pixels(pixelWidth)
    + '" height="' + pixels(pixelHeight) + '" viewBox="0 0 16 16">';
  if (shape === defaultShape) {
    // Vivid theme-derived fills stay distinct from the solid foreground body.
    // Adjust brightness without mixing in grey, preserving the seed hue.
    function rgb(color) {
      return [1,3,5].map(function(i){return parseInt(color.slice(i,i+2),16)/255;});
    }
    function luminance(channels) {
      var linear=channels.map(function(v){return v<=0.04045?v/12.92:Math.pow((v+0.055)/1.055,2.4);});
      return linear[0]*0.2126+linear[1]*0.7152+linear[2]*0.0722;
    }
    function contrast(fill) {
      var base=rgb(paper.color);
      function visible(p) {return rgb(p.color).map(function(v,i){return v*p.alpha+base[i]*(1-p.alpha);});}
      var a=luminance(visible(fill)),b=luminance(visible(ink));
      return (Math.max(a,b)+0.05)/(Math.min(a,b)+0.05);
    }
    var accentInk=paint(accentColor, "#81a1c1");
    function gaugePaint(fill,value) {
      var normal=value<0.65,seed=normal?accentInk:fill;
      var channels=rgb(seed.color),low=Math.min.apply(null,channels),high=Math.max.apply(null,channels);
      if(high-low<0.01) {
        channels=rgb(value>=0.85?"#bf616a":"#81a1c1");
        low=Math.min.apply(null,channels);high=Math.max.apply(null,channels);
      }
      var saturation=Math.max(0.9,(high-low)/high);
      var hue=channels.map(function(v){return 1-saturation+saturation*(v-low)/(high-low);});
      var ceiling=normal?0.8:1;
      for(var step=0;step<20;step++) {
        var brightness=ceiling-step*0.05;
        if(brightness<=0) break;
        var candidate={color:'#'+hue.map(function(v){return Math.round(255*v*brightness).toString(16).padStart(2,'0');}).join(''),alpha:ink.alpha};
        if(contrast(candidate)>=3) return candidate;
      }
      return {color:paper.color,alpha:ink.alpha};
    }
    cpuInk=gaugePaint(cpuInk,c);ramInk=gaugePaint(ramInk,r);
    function cells(x,value,fill,axis) {
      var out='<g id="'+axis+'-cells">', active=Math.floor(value*6);
      for(var row=0;row<6;row++) {
        var paint=row<active?fill:ink;
        out+='<rect x="'+x+'" y="'+(9-row)+'" width="3" height="1" fill="'+paint.color
          +'" opacity="'+(paint.alpha*(row<active?1:0.28))+'"/>';
      }
      return out+'</g>';
    }
    var fire='';
    if(severity>0) {
      var top=severity===1
        ? 'M5 2V1H6V0H7V1H8V3H6V2Z M10 3V1H11V0H12V1H13V2H12V3Z'
        : 'M3 3V1H4V0H6V1H7V0H8V3H6V4H4V3Z M9 3V0H10V1H11V0H13V1H14V3H12V4H10V3Z';
      var side=severity>=3?' M2 6H1V7H0V8H1V10H2V9H3V7H2Z M14 6H15V7H16V8H15V10H14V9H13V7H14Z':'';
      var bottom=severity>=4?' M4 13H6V14H7V15H6V16H5V15H4Z M10 13H12V14H13V15H12V16H11V15H10Z':'';
      fire='<path d="'+top+side+bottom+'" fill="'+heat.color+'" opacity="'+heat.alpha+'"/>';
    }
    return svgStart+'<path fill="'+ink.color+'" fill-opacity="'+ink.alpha+'" fill-rule="evenodd" d="'+bodies[shape]+'"/>'
      +cells(4,c,cpuInk,'cpu')+cells(9,r,ramInk,'ram')+fire+'</svg>';
  }
  var lx = wedge ? 6.3 : 5.15, ly = wedge ? 6.8 : 5.8;
  var x = wedge ? 8.5 : 8.65, y = wedge ? 6 : (wide ? 5 : 4.3);
  // Leave a visible gap above the wider mouth instead of merging CPU with RAM.
  var w = wedge ? 2 : 2.5, h = wedge ? 2.7 : (wide ? 3.2 : 4.2);
  var mx = wedge ? 5.1 : (shape === 4 ? 5.4 : 5), my = wide ? 10 : 10.3;
  var qx = 8, qy = wide ? 10.5 : 10.9;
  var ex = wedge ? 10.7 : (shape === 4 ? 10.6 : 11), ey = my;
  var mouth = "M" + mx + " " + my + " Q" + qx + " " + qy + " " + ex + " " + ey;
  var px = (1-c)*(1-c)*mx + 2*(1-c)*c*qx + c*c*ex;
  var py = (1-c)*(1-c)*my + 2*(1-c)*c*qy + c*c*ey;
  function flame(x,y,scale) {
    return '<path transform="translate('+x+' '+y+') scale('+scale+')" d="M-0.9 0 C-1.5 -0.65 -0.3 -1.3 -0.5 -2.1 Q0.35 -1.75 0.4 -1 Q0.8 -1.2 0.75 -1.65 C1.75 -0.5 1.15 0.45 0.1 0.5 Q-0.5 0.5 -0.9 0 Z"/>';
  }
  var flames = '';
  if (severity>0) {
    var upperScale=severity===1?0.95:1.4;
    flames=flame(5.4,3.2,upperScale)+flame(10.3,3.2,upperScale);
    if(severity>=3) flames+=flame(1.7,7.2,0.9)+flame(14.3,8,0.9);
    if(severity>=4) flames+=flame(5.2,14.5,1)+flame(10.7,14.5,1);
  }
  return svgStart
    + '<g stroke="' + ink.color + '" stroke-opacity="' + ink.alpha + '" stroke-linecap="round" stroke-linejoin="round">'
    + '<path d="M5.6 3.3 5.4 1.9 M10.1 3.3 10.3 1.9 M3.3 7 1.65 7 M12.7 8 14.35 8 M5.4 12.5 5.2 14.1 M10.4 12.5 10.7 14.1" fill="none" stroke-width="1.05"/>'
    + '<path d="' + bodies[shape] + '" fill="' + paper.color + '" fill-opacity="' + paper.alpha + '" stroke-width="0.9"/></g>'
    + (severity>0 ? '<g fill="' + heat.color + '" opacity="' + heat.alpha + '">' + flames + '</g>' : '')
    + '<g fill="' + ink.color + '" opacity="' + ink.alpha + '">'
    + '<ellipse cx="' + lx + '" cy="' + ly + '" rx="0.85" ry="1"/>'
    + '<rect x="' + x + '" y="' + y + '" width="' + w + '" height="' + h + '" rx="' + w/2 + '" opacity="0.32"/>'
    + '</g>'
    + (r > 0 ? '<rect x="' + x + '" y="' + (y+h*(1-r)).toFixed(3) + '" width="' + w + '" height="' + (h*r).toFixed(3) + '" rx="' + Math.min(w/2,h*r/2).toFixed(3) + '" fill="' + ramInk.color + '" opacity="' + ramInk.alpha + '"/>' : '')
    + '<g fill="none" stroke="' + ink.color + '" stroke-opacity="' + ink.alpha + '" stroke-width="2.4" stroke-linecap="round">'
    + '<path d="' + mouth + '" opacity="0.32"/>'
    + '</g>'
    + (c > 0 ? '<path d="M' + mx + ' ' + my + ' Q' + (mx+(qx-mx)*c).toFixed(3) + ' ' + (my+(qy-my)*c).toFixed(3) + ' ' + px.toFixed(3) + ' ' + py.toFixed(3) + '" fill="none" stroke="' + cpuInk.color + '" stroke-opacity="' + cpuInk.alpha + '" stroke-width="2.4" stroke-linecap="round"/>' : '') + '</svg>';
}
