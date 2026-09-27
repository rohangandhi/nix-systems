import assert from 'node:assert/strict';
import test from 'node:test';
import {bytes, percent, cpuUsage, level, thermalEdges, rangeText} from '../format.js';

test('missing readings stay unknown instead of becoming zero', () => {
    for (const value of [undefined, null, NaN, Infinity]) {
        assert.equal(bytes(value), '—');
        assert.equal(percent(value), '—');
    }
    assert.equal(bytes(0), '0 B');
    assert.equal(bytes(18 * 1024 ** 3, true), '18.0G');
    assert.equal(bytes(18 * 1024 ** 3), '18.0 GiB');
});

test('CPU uses deltas and survives counter resets', () => {
    assert.equal(cpuUsage(null, {total: 100, idle: 80}), null);
    assert.equal(cpuUsage({total: 100, idle: 80}, {total: 200, idle: 150}), 30);
    assert.equal(cpuUsage({total: 100, idle: 80}, {total: 100, idle: 80}), null);
    assert.equal(cpuUsage({total: 100, idle: 80}, {total: 10, idle: 8}), null);
    assert.equal(percent(150), '100%');
});

test('five bands preserve unknown readings and include their lower boundaries', () => {
    assert.equal(level(null), null);
    assert.equal(level(-1), null);
    assert.equal(level(0), 0);
    assert.equal(level(19.9), 0);
    assert.equal(level(20), 1);
    assert.equal(level(100), 4);
    assert.equal(level(200), 4);
});

test('normal load temperatures have headroom; edge and CPU limits remain distinct', () => {
    assert.equal(level(79, thermalEdges(95)), 2);
    assert.equal(level(89, thermalEdges(95)), 3);
    assert.equal(level(90, thermalEdges(95)), 4);
    assert.equal(level(90, thermalEdges(100)), 3);
    assert.equal(level(95, thermalEdges(100)), 4);
    assert.equal(rangeText(61, thermalEdges(100), '°C'), '60–80 °C');
    assert.equal(rangeText(null, thermalEdges(100), '°C'), 'Unavailable');
});
