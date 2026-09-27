export function bytes(value, compact = false) {
    if (!Number.isFinite(value) || value < 0)
        return '—';
    const units = compact ? ['B', 'K', 'M', 'G', 'T'] : ['B', 'KiB', 'MiB', 'GiB', 'TiB'];
    let index = 0;
    while (value >= 1024 && index < units.length - 1) {
        value /= 1024;
        index++;
    }
    const digits = index > 0 && value < 100 ? 1 : 0;
    return `${value.toFixed(digits)}${compact ? '' : ' '}${units[index]}`;
}

export function percent(value) {
    return Number.isFinite(value) ? `${Math.round(Math.max(0, Math.min(100, value)))}%` : '—';
}

export function cpuUsage(previous, current) {
    if (!previous || !current)
        return null;
    const total = current.total - previous.total;
    const idle = current.idle - previous.idle;
    if (total <= 0 || idle < 0)
        return null;
    return Math.max(0, Math.min(100, 100 * (total - idle) / total));
}

export function level(value, edges = [20, 40, 60, 80]) {
    if (!Number.isFinite(value) || value < 0)
        return null;
    return edges.filter(edge => value >= edge).length;
}

// Broad operating bands, with the last shade reserved for temperatures near
// this host's limits (95°C CPU Tctl / 100°C GPU edge, not hotspot).
export function thermalEdges(limit = 100) {
    return [40, 60, 80, Math.max(85, (limit ?? 100) - 5)];
}

export function rangeText(value, edges, unit) {
    const band = level(value, edges);
    if (band === null)
        return 'Unavailable';
    if (band === 0)
        return `Below ${edges[0]} ${unit}`;
    if (band === edges.length)
        return `${edges.at(-1)} ${unit} and above`;
    return `${edges[band - 1]}–${edges[band]} ${unit}`;
}
