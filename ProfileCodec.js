.pragma library

// ASCII profile payloads use the same encoding on Qt 6.8 and Qt 6.12.
function encode(value) {
  var source = JSON.stringify(value)
  var alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
  var result = ""
  for (var i = 0; i < source.length; i += 3) {
    var a = source.charCodeAt(i), b = source.charCodeAt(i + 1), c = source.charCodeAt(i + 2)
    result += alphabet[a >> 2] + alphabet[((a & 3) << 4) | (isNaN(b) ? 0 : b >> 4)]
    result += isNaN(b) ? "=" : alphabet[((b & 15) << 2) | (isNaN(c) ? 0 : c >> 6)]
    result += isNaN(c) ? "=" : alphabet[c & 63]
  }
  return result
}
