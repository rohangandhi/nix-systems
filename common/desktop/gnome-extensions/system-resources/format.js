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

// Equal-width fields keep the slash aligned across all capacity rows.
export function capacity(used, total) {
    return `${bytes(used).padStart(9)} / ${bytes(total).padStart(9)}`;
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
