.pragma library

var alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"

function encode(value) {
  var source = encodeURIComponent(JSON.stringify(value)).replace(/%([0-9A-F]{2})/g, function(match, byte) {
    return String.fromCharCode(parseInt(byte, 16))
  })
  var result = ""
  for (var i = 0; i < source.length; i += 3) {
    var a = source.charCodeAt(i), b = source.charCodeAt(i + 1), c = source.charCodeAt(i + 2)
    result += alphabet[a >> 2] + alphabet[((a & 3) << 4) | (isNaN(b) ? 0 : b >> 4)]
    result += isNaN(b) ? "=" : alphabet[((b & 15) << 2) | (isNaN(c) ? 0 : c >> 6)]
    result += isNaN(c) ? "=" : alphabet[c & 63]
  }
  return result
}

function decode(payload) {
  if (!/^[A-Za-z0-9_-]+={0,2}$/.test(payload)) throw new Error("Invalid profile encoding")
  var source = payload.replace(/=+$/, "")
  if (source.length % 4 === 1 || (source.length !== payload.length && payload.length % 4 !== 0))
    throw new Error("Invalid profile padding")
  var escaped = ""
  var bits = 0, count = 0
  for (var i = 0; i < source.length; i++) {
    bits = (bits << 6) | alphabet.indexOf(source[i])
    count += 6
    if (count >= 8) {
      count -= 8
      escaped += "%" + ((bits >> count) & 255).toString(16).padStart(2, "0")
    }
  }
  if (bits & ((1 << count) - 1)) throw new Error("Invalid profile padding bits")
  return JSON.parse(decodeURIComponent(escaped))
}
