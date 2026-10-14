// Vector concept only. Values and colors are supplied by the inert consumer.
function iconSvg(cpu, ram, fresh, foreground, background) {
    function fraction(value) {
        return fresh && isFinite(value) && value >= 0
            ? Math.max(0, Math.min(100, value)) / 100 : 0;
    }
    function color(value, fallback) {
        return /^#[0-9a-f]{6}$/i.test(String(value)) ? String(value) : fallback;
    }
    var ink = color(foreground, "#d8dee9");
    var paper = color(background, "#2e3440");
    var c = fraction(cpu), r = fraction(ram);
    var valid = fresh && isFinite(cpu) && cpu >= 0 && isFinite(ram) && ram >= 0;
    // Split the quadratic smile at c; Qt SVG need not support stroke clipping.
    var controlX = 4.9 + (6.55 - 4.9) * c;
    var controlY = 9.55 + (11.2 - 9.55) * c;
    var endX = (1 - c) * (1 - c) * 4.9 + 2 * (1 - c) * c * 6.55 + c * c * 8.65;
    var endY = (1 - c) * (1 - c) * 9.55 + 2 * (1 - c) * c * 11.2 + c * c * 9.95;
    return [
        '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16">',
        '  <g stroke="' + ink + '" stroke-width="1.05" stroke-linecap="round" stroke-linejoin="round">',
        '    <path d="M6.6 3.1 6.3 1.35 M5.5 12.9 5.2 14.6 M10.1 12.9 10.6 14.1 M3.3 8.5 1.35 9.05 M12.7 7.8 Q14.55 7.9 14.55 6.65" fill="none"/>',
        '    <path d="M5.55 3.15 C3.6 3.35 3.2 4.75 3.45 6.55 L3.7 10.6 C3.8 12.45 4.95 13.05 6.4 12.95 L10.25 12.75 C12.2 12.65 12.85 11.65 12.7 9.65 L12.5 5.2 C12.4 3.45 11.1 2.7 9.45 2.95 Z" fill="' + paper + '"/>',
        '  </g>',
        '  <path d="M4.7 4.65 Q5.55 4.05 6.35 4.6" fill="none" stroke="' + ink + '" stroke-width="0.65" stroke-linecap="round"/>',
        '  <ellipse cx="5.6" cy="6.3" rx="0.8" ry="1.05" fill="' + ink + '"/>',
        '  <rect x="9.05" y="4.3" width="2.5" height="5.4" rx="1.25" fill="' + ink + '" fill-opacity="0.18"/>',
        '  <rect x="9.05" y="' + (9.7 - 5.4 * r).toFixed(3) + '" width="2.5" height="' + (5.4 * r).toFixed(3) + '" rx="' + Math.min(1.25, 2.7 * r).toFixed(3) + '" fill="' + ink + '"/>',
        '  <rect x="9.05" y="4.3" width="2.5" height="5.4" rx="1.25" fill="none" stroke="' + ink + '" stroke-opacity="' + (valid ? '0.8' : '0.45') + '" stroke-width="0.55"/>',
        '  <ellipse cx="10.25" cy="6.3" rx="0.45" ry="0.7" fill="' + paper + '" stroke="' + ink + '" stroke-width="0.3"/>',
        '  <path d="M4.9 9.55 Q6.55 11.2 8.65 9.95" fill="none" stroke="' + ink + '" stroke-opacity="0.3" stroke-width="1.25" stroke-linecap="round"/>',
        c > 0 ? '  <path d="M4.9 9.55 Q' + controlX.toFixed(3) + ' ' + controlY.toFixed(3) + ' ' + endX.toFixed(3) + ' ' + endY.toFixed(3) + '" fill="none" stroke="' + ink + '" stroke-width="1.25" stroke-linecap="round"/>' : '',
        '</svg>'
    ].join('\n') + '\n';
}
