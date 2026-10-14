// Fifty vector concepts: ten silhouettes, each with five distinct face geometries.
var bodies = [
    {name: "Soft chip", path: "M5 3 Q3 3 3 5 L3 11 Q3 13 5 13 L11 13 Q13 13 13 11 L13 5 Q13 3 11 3 Z"},
    {name: "Leaning chip", path: "M5 3.4 L10.8 2.8 Q12.5 2.6 12.7 4.8 L13.2 10.6 Q13.4 12.4 11.2 12.7 L5.2 13.3 Q3.5 13.4 3.3 11.3 L2.8 5.4 Q2.7 3.6 5 3.4 Z"},
    {name: "Pebble", path: "M3.1 6.6 C3 3.2 5.7 2.4 8.5 2.7 C12 2.6 13.5 5.1 13.1 8.7 C13 12 10.7 13.5 7.3 13.1 C3.9 13 2.7 10.6 3.1 6.6 Z"},
    {name: "Bean", path: "M6 2.8 C9 1.8 12.9 3.5 13 7.2 C13.6 11.5 10.8 13.4 7.6 13 C4.3 13.3 2.2 11.2 3.5 8.7 C4.5 7 2.6 4 6 2.8 Z"},
    {name: "Tall capsule", path: "M3.7 6 Q3.7 2.4 8 2.4 Q12.3 2.4 12.3 6 L12.3 10 Q12.3 13.6 8 13.6 Q3.7 13.6 3.7 10 Z"},
    {name: "Wide capsule", path: "M6 3.8 L10 3.8 Q13.8 3.8 13.8 8 Q13.8 12.2 10 12.2 L6 12.2 Q2.2 12.2 2.2 8 Q2.2 3.8 6 3.8 Z"},
    {name: "Little ghost", path: "M3 7 Q3 2.7 8 2.7 Q13 2.7 13 7 L13 12.6 Q11.4 13.6 10 12.2 Q8 14 6 12.2 Q4.4 13.7 3 12.6 Z"},
    {name: "Dome", path: "M3.3 7.7 Q3.3 2.7 8 2.7 Q12.7 2.7 12.7 7.7 L12.7 11.3 Q12.7 13 11 13 L5 13 Q3.3 13 3.3 11.3 Z"},
    {name: "Soft wedge", path: "M6.2 3 Q8 1.8 9.4 3.2 L13 9.5 Q14.4 12.5 11.4 12.8 L4.4 13 Q1.8 12.8 3 10 Z"},
    {name: "Round friend", path: "M13.2 8 A5.2 5.2 0 1 1 2.8 8 A5.2 5.2 0 1 1 13.2 8 Z"}
];
var faces = [
    {name: "Smile", left: [5.2, 5.5, 0.72, 0.72], eye: [9.25, 4.4, 1.65, 4.4], mouth: [4.9, 9.65, 6.7, 11.3, 9, 9.85]},
    {name: "Quiet", left: [5.4, 6, 0.65, 1.05], eye: [9.3, 4.7, 1.5, 4.6], mouth: [4.8, 10.15, 6.6, 10.15, 8.6, 10.15]},
    {name: "Smirk", left: [5.25, 5.7, 1.05, 0.55], eye: [9.6, 4.4, 1.25, 4.9], mouth: [4.75, 10.3, 6.65, 10.65, 8.85, 9.55]},
    {name: "Wonder", left: [5.4, 5.55, 0.82, 1.15], eye: [9.1, 4.7, 1.85, 3.7], mouth: [5.05, 10.25, 6.9, 8.65, 8.8, 10.3]},
    {name: "Sleepy", left: [5.35, 6.1, 1.05, 0.45], eye: [9.25, 5.2, 1.8, 3.7], mouth: [4.9, 9.9, 6.8, 11, 8.9, 10.5]}
];
// Appendages are silhouette strokes, never face decorations.
var limbs = [
    "M5.3 13 4.9 14.3 M10.4 13 10.8 14.1",
    "",
    "M3 8.3 1.4 8.8 M13 7.8 Q14.6 7.9 14.6 6.8",
    "M6.1 2.8 5.7 1.4 M5.3 13 5 14.4 M10.5 13 11 14.1",
    "M3 8 1.5 7.5 M13 8 14.5 8.6"
];

function variants() {
    var result = [];
    for (var b = 0; b < bodies.length; ++b)
        for (var f = 0; f < faces.length; ++f)
            result.push({number: b * 5 + f + 1, name: bodies[b].name + " / " + faces[f].name});
    return result;
}

function svg(number, cpu, ram, fresh) {
    number = Math.max(1, Math.min(50, Math.floor(Number(number) || 1)));
    var body = bodies[Math.floor((number - 1) / 5)];
    var faceIndex = (number - 1) % 5;
    var face = faces[faceIndex];
    var ink = "#d8dee9", paper = "#2e3440";
    function level(value) {
        return fresh && isFinite(value) && value >= 0 ? Math.min(100, value) / 100 : 0;
    }
    var c = level(cpu), r = level(ram), eye = face.eye, mouth = face.mouth;
    var left = face.left;
    if (number >= 41 && number <= 45) {
        // A wedge narrows at the top: keep every facial stroke inside its contour.
        left = [6.3, 6.3, face.left[2] * 0.8, face.left[3] * 0.8];
        eye = [8.9, 6.0, face.eye[2] * 0.7, face.eye[3] * 0.64];
        mouth = [5.8, face.mouth[1] + 0.2, 7.25, face.mouth[3] + 0.2, 9.2, face.mouth[5] + 0.2];
    }
    var ex = mouth[0] * (1-c) * (1-c) + 2 * mouth[2] * (1-c) * c + mouth[4] * c*c;
    var ey = mouth[1] * (1-c) * (1-c) + 2 * mouth[3] * (1-c) * c + mouth[5] * c*c;
    var cx = mouth[0] + (mouth[2]-mouth[0]) * c;
    var cy = mouth[1] + (mouth[3]-mouth[1]) * c;
    var track = "M" + mouth[0] + " " + mouth[1] + " Q" + mouth[2] + " " + mouth[3] + " " + mouth[4] + " " + mouth[5];
    return '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16">\n'
        + '<g stroke="' + ink + '" stroke-width="1.05" stroke-linecap="round" stroke-linejoin="round">'
        + (limbs[faceIndex] ? '<path d="' + limbs[faceIndex] + '" fill="none"/>' : '')
        + '<path d="' + body.path + '" fill="' + paper + '"/></g>\n'
        + '<ellipse cx="' + left[0] + '" cy="' + left[1] + '" rx="' + left[2] + '" ry="' + left[3] + '" fill="' + ink + '"/>\n'
        + '<rect x="' + eye[0] + '" y="' + eye[1] + '" width="' + eye[2] + '" height="' + eye[3] + '" rx="' + eye[2]/2 + '" fill="' + ink + '" opacity="0.25"/>\n'
        + (r > 0 ? '<rect x="' + eye[0] + '" y="' + (eye[1]+eye[3]*(1-r)).toFixed(3) + '" width="' + eye[2] + '" height="' + (eye[3]*r).toFixed(3) + '" rx="' + Math.min(eye[2]/2,eye[3]*r/2).toFixed(3) + '" fill="' + ink + '"/>\n' : '')
        + '<path d="' + track + '" fill="none" stroke="' + ink + '" opacity="0.25" stroke-width="1.1" stroke-linecap="round"/>\n'
        + (c > 0 ? '<path d="M' + mouth[0] + ' ' + mouth[1] + ' Q' + cx.toFixed(3) + ' ' + cy.toFixed(3) + ' ' + ex.toFixed(3) + ' ' + ey.toFixed(3) + '" fill="none" stroke="' + ink + '" stroke-width="1.1" stroke-linecap="round"/>\n' : '')
        + '</svg>\n';
}
