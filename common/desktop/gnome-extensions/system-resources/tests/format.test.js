import assert from 'node:assert/strict';
import test from 'node:test';
import {bytes, capacity, percent, cpuUsage} from '../format.js';

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

test('capacity columns keep the slash in one position despite different units', () => {
    for (const [used, total] of [[0, 8 * 1024 ** 3], [1.5 * 1024 ** 3, 64 * 1024 ** 3],
        [402 * 1024 ** 3, 491 * 1024 ** 3], [6 * 1024 ** 3, 1024 ** 4]]) {
        assert.equal(capacity(used, total).indexOf('/'), 10);
        assert.equal(capacity(used, total).length, 21);
    }
});
