// Concept inputs: explicit hot flag plus separate temperature freshness.
// No hardware threshold or collection policy is defined by these drawings.
function svg(bodyPath, shape, cpu, ram, fresh, hot, temperatureFresh, heatStyle) {
    var ink = "#d8dee9", paper = "#2e3440", warm = "#ebcb8b";
    function level(value) {
        return fresh && typeof value === "number" && isFinite(value) && value >= 0
            ? Math.min(100, value) / 100 : 0;
    }
    var c = level(cpu), r = level(ram);
    var alert = hot === true && temperatureFresh === true;
    var wide = shape === 5;
    // Faces are kept clear of the narrow top of the triangular silhouette.
    var wedge = shape === 8;
    var leftX = wedge ? 6.3 : 5.15, leftY = wedge ? 6.8 : 5.8;
    var eyeX = wedge ? 8.5 : 8.65, eyeY = wedge ? 6.0 : (wide ? 5.0 : 4.3);
    var eyeW = wedge ? 2.0 : 2.5, eyeH = wedge ? 3.1 : (wide ? 3.8 : 5.0);
    var mx = wedge ? 5.4 : 4.9, my = wide ? 10.0 : 10.15;
    var qx = wedge ? 7.15 : 6.75, qy = wide ? 11.0 : 11.45;
    var endX = wedge ? 9.45 : 9.5, endY = wide ? 10.15 : 10.5;
    var mouth = "M" + mx + " " + my + " Q" + qx + " " + qy + " " + endX + " " + endY;
    var px = (1-c)*(1-c)*mx + 2*(1-c)*c*qx + c*c*endX;
    var py = (1-c)*(1-c)*my + 2*(1-c)*c*qy + c*c*endY;
    var pinColor = alert && heatStyle === 1 ? warm : ink;
    var pins = '<path d="M5.6 3.3 5.4 1.9 M10.1 3.3 10.3 1.9 M3.3 7 1.65 7 M12.7 8 14.35 8 M5.4 12.5 5.2 14.1 M10.4 12.5 10.7 14.1" fill="none" stroke="' + pinColor + '" stroke-width="1.05" stroke-linecap="round"/>';
    var fireColor = heatStyle === 2 ? warm : ink;
    // Two solid flames replace upper pin tips. They stay inside the same 16px slot.
    var fire = alert && heatStyle !== 1
        ? '<g fill="' + fireColor + '"><path d="M4.4 2.9 C3.9 2.1 4.7 1.4 4.6 0.9 Q5.25 1.1 5.4 1.8 Q5.65 1.4 5.6 1.1 C6.8 2.4 6.15 3.2 5.35 3.25 Q4.75 3.25 4.4 2.9 Z"/><path d="M9.4 2.9 C8.9 2.1 9.7 1.4 9.6 0.9 Q10.25 1.1 10.4 1.8 Q10.65 1.4 10.6 1.1 C11.8 2.4 11.15 3.2 10.35 3.25 Q9.75 3.25 9.4 2.9 Z"/></g>' : '';
    return '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16">\n'
        + pins + '<path d="' + bodyPath + '" fill="' + paper + '" stroke="' + ink + '" stroke-width="0.9" stroke-linejoin="round"/>'
        + fire
        + '<ellipse cx="' + leftX + '" cy="' + leftY + '" rx="0.85" ry="1.0" fill="' + ink + '"/>'
        + '<rect x="' + eyeX + '" y="' + eyeY + '" width="' + eyeW + '" height="' + eyeH + '" rx="' + eyeW/2 + '" fill="' + ink + '" opacity="0.32"/>'
        + (r > 0 ? '<rect x="' + eyeX + '" y="' + (eyeY+eyeH*(1-r)).toFixed(3) + '" width="' + eyeW + '" height="' + (eyeH*r).toFixed(3) + '" rx="' + Math.min(eyeW/2,eyeH*r/2).toFixed(3) + '" fill="' + ink + '"/>' : '')
        + '<path d="' + mouth + '" fill="none" stroke="' + ink + '" opacity="0.32" stroke-width="1.65" stroke-linecap="round"/>'
        + (c > 0 ? '<path d="M' + mx + ' ' + my + ' Q' + (mx+(qx-mx)*c).toFixed(3) + ' ' + (my+(qy-my)*c).toFixed(3) + ' ' + px.toFixed(3) + ' ' + py.toFixed(3) + '" fill="none" stroke="' + ink + '" stroke-width="1.65" stroke-linecap="round"/>' : '')
        + '</svg>\n';
}
