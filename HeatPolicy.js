// Shared thermal severity. Thresholds are display preferences, not Tjmax.
function nextLevel(current, temperature, threshold, fresh) {
  if (!fresh || typeof temperature !== "number" || !isFinite(temperature) || temperature <= 0) return 0;
  if (temperature < threshold - 5) return 0;
  var desired = temperature >= threshold ? Math.min(4, 1 + Math.floor((temperature - threshold) / 5)) : 0;
  if (current === 0 || desired >= current) return desired;
  // Two-degree cooling deadband between severity levels; five at alert exit.
  while (current > 1 && temperature < threshold + (current - 1) * 5 - 2) --current;
  return current;
}
function interval(level) { return [0, 15000, 10000, 5000, 3000][Math.max(0, Math.min(4, level))]; }
