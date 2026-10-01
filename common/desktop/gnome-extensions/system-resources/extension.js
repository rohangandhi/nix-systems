import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Shell from 'gi://Shell';
import St from 'gi://St';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';

import {bytes, cpuUsage, percent} from './format.js';
import {box, Capacity, grid, label, Metric, sensor, Tooltips} from './widgets.js';

export default class SystemResources extends Extension {
    enable() {
        // Every async callback belongs to this enable cycle, even after re-enable.
        const state = {active: true, busy: false, process: null, timeout: 0,
            cancellable: null, previousCpu: null, previousThreads: new Map(), storageAt: 0, timer: 0,
            networkAt: 0, network: {busy: false, process: null, timeout: 0, cancellable: null}};
        this._state = state;
        this._indicator = new PanelMenu.Button(0, 'System Resources');
        const panel = box(false, 'system-resources-panel');
        this._values = {};
        for (const name of ['CPU', 'GPU', 'RAM']) {
            const value = label('—', {style_class: `system-resources-value ${name === 'RAM'
                ? 'system-resources-memory' : 'system-resources-percent'}`, accessible_name: name});
            panel.add_child(value);
            this._values[name] = value;
        }
        this._indicator.add_child(panel);
        this._buildMenu();
        Main.panel.addToStatusArea(this.uuid, this._indicator, 0, 'right');
        this._indicator.menu.connect('open-state-changed', (_menu, open) => {
            this._tooltips.hide();
            if (open) {
                this._disks.values().next().value.actor.grab_key_focus();
                // Opening the menu establishes keyboard focus without placing
                // a tooltip over it before the user points at a reading.
                this._tooltips.hide();
                void this._poll(state);
                void this._pollNetwork(state);
            } else {
                state.previousThreads.clear();
            }
        });
        void this._poll(state);
        state.timer = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 2, () => {
            void this._poll(state);
            void this._pollNetwork(state);
            return GLib.SOURCE_CONTINUE;
        });
    }

    _buildMenu() {
        this._tooltips = new Tooltips();
        this._indicator.menu.box.add_style_class_name('quick-settings');
        this._content = box(true, 'sr-content');
        this._indicator.menu.box.add_child(this._content);
        this._content.connect('key-press-event', (_actor, event) => {
            const key = event.get_key_symbol();
            const directions = new Map([[Clutter.KEY_Left, St.DirectionType.LEFT],
                [Clutter.KEY_Right, St.DirectionType.RIGHT], [Clutter.KEY_Up, St.DirectionType.UP],
                [Clutter.KEY_Down, St.DirectionType.DOWN], [Clutter.KEY_Tab, St.DirectionType.TAB_FORWARD],
                [Clutter.KEY_ISO_Left_Tab, St.DirectionType.TAB_BACKWARD]]);
            if (!directions.has(key))
                return Clutter.EVENT_PROPAGATE;
            return this._content.navigate_focus(global.stage.get_key_focus(), directions.get(key), true)
                ? Clutter.EVENT_STOP : Clutter.EVENT_PROPAGATE;
        });

        // One six-column grid makes every tile equal, including across groups.
        this._storage = grid(6);
        this._storage.add(label('Volatile Storage', {style_class: 'sr-section-title'}), 0, 2);
        this._storage.add(label('Persistent Storage', {style_class: 'sr-section-title'}), 2, 4);
        this._disks = new Map();
        const paths = [['/', 'Root'], [GLib.get_home_dir(), 'Home'], ['/p-home', 'P-Home'],
            ['/p-data', 'P-Data'], ['/p-shared', 'P-Shared'], ['/p-os', 'P-OS']];
        paths.forEach(([path, name], index) => {
            const tile = new Capacity(name, this._tooltips, {path, open: p => this._openDirectory(p)});
            this._disks.set(path, tile);
            this._storage.add(tile.actor, index + 6);
        });
        this._content.add_child(this._storage);

        this._resources = grid(2);
        this._cpu = this._buildCard('CPU', '…', 'RAM');
        this._gpu = this._buildCard('GPU', 'Radeon', 'VRAM');
        this._resources.add(this._cpu.actor, 0);
        this._resources.add(this._gpu.actor, 1);
        this._content.add_child(this._resources);
        this._buildNetwork();
        this._cores = new Map();
        this._coreSignature = '';
        this._engines = [
            ['busy', 'Graphics activity', 'graphics'],
            ['memoryBusy', 'Memory activity', 'memory'],
            ['videoBusy', 'Video activity', 'video'],
        ].map(([key, name, icon], index) => {
            const metric = new Metric(this._tooltips, {gicon: this._icon(icon)});
            metric.key = key;
            metric.name = name;
            this._gpu.grid.add(metric.actor, index);
            return metric;
        });
        this._clearReadings();
    }

    _buildCard(title, hardware, memory) {
        const actor = box(true, 'quick-toggle-menu sr-card', {reactive: true, x_expand: true});
        const header = box(false, 'sr-card-header');
        header.add_child(label(title, {style_class: 'sr-heading', x_expand: true}));
        const subtitle = label(hardware, {style_class: 'sr-muted sr-hardware'});
        header.add_child(subtitle);
        actor.add_child(header);
        const activity = box(false, 'sr-activity');
        const metrics = grid(3, 4, true);
        activity.add_child(metrics);
        const sensors = box(true, 'sr-sensors');
        const temperature = new Metric(this._tooltips, {gicon: this._icon('temperature'), ring: true});
        const power = new Metric(this._tooltips, {gicon: this._icon('power'), ring: true});
        sensors.add_child(temperature.actor);
        sensors.add_child(power.actor);
        activity.add_child(sensors);
        actor.add_child(activity);
        const capacity = new Capacity(memory, this._tooltips);
        actor.add_child(capacity.actor);
        const consumers = box(true, 'sr-consumers');
        const apps = Array.from({length: 3}, () => {
            const row = box(false, 'sr-consumer');
            const name = label('—', {style_class: 'sr-muted', x_expand: true});
            const value = label('', {style_class: 'system-resources-value'});
            row.add_child(name);
            row.add_child(value);
            consumers.add_child(row);
            return {actor: row, name, value};
        });
        actor.add_child(consumers);
        return {actor, subtitle, activity, grid: metrics, temperature, power, capacity, apps};
    }

    _icon(name) {
        return new Gio.FileIcon({file: Gio.File.new_for_path(`${this.path}/icons/${name}-symbolic.svg`)});
    }

    _buildNetwork() {
        const actor = box(true, 'quick-toggle-menu sr-network', {reactive: true, x_expand: true});
        const header = box(false, 'sr-card-header sr-network-header');
        header.add_child(label('Network', {style_class: 'sr-heading', x_expand: true}));
        const subtitle = label('…', {style_class: 'sr-muted sr-hardware'});
        header.add_child(subtitle);
        actor.add_child(header);
        const columns = grid(3, 8);
        const entries = {};
        for (const [index, name] of ['DNS', 'NAS', 'Router'].entries()) {
            const content = box(true, 'sr-network-content', {x_expand: true});
            content.add_child(label(name, {style_class: 'sr-network-name'}));
            const value = label('—', {style_class: 'system-resources-value sr-network-value'});
            const detail = label('Unavailable', {style_class: 'sr-muted sr-network-detail'});
            content.add_child(value);
            content.add_child(detail);
            const entry = name === 'DNS' ? box(true, 'sr-network-entry') : new St.Button({
                style_class: 'popup-menu-item sr-network-entry', x_expand: true, can_focus: true});
            if (name === 'DNS')
                entry.add_child(content);
            else {
                entry.set_child(content);
                entry.connect('clicked', () => {
                    if (entries[name].url)
                        this._openUri(entries[name].url);
                });
            }
            this._tooltips.bind(entry);
            columns.add(entry, index);
            entries[name] = {actor: entry, value, detail, url: null};
        }
        actor.add_child(columns);
        this._content.add_child(actor);
        this._network = {actor, subtitle, entries};
        this._updateNetwork(null);
    }

    _updateNetwork(data) {
        const {subtitle, entries} = this._network;
        subtitle.text = data?.interface
            ? [data.interface, data.address?.split('/')[0]].filter(Boolean).join(' · ')
            : data ? 'No default route' : 'Unavailable';
        const dns = data?.dns ?? [];
        entries.DNS.value.text = dns[0] ?? '—';
        entries.DNS.detail.text = dns.length > 1 ? dns[1] + (dns.length > 2 ? ` +${dns.length - 2}` : '')
            : dns.length ? 'System resolver' : 'Unavailable';
        entries.DNS.detail.add_style_class_name('system-resources-value');
        const upstream = data?.upstreamDns?.filter(server => !dns.includes(server)) ?? [];
        this._tooltips.set(entries.DNS.actor, dns.length
            ? `System DNS servers\n${dns.join('\n')}` + (upstream.length
                ? `\nConnection DNS servers\n${upstream.join('\n')}` : '')
            : 'System DNS servers · Unavailable');
        for (const [name, device] of [['NAS', data?.nas], ['Router', data?.router]]) {
            const entry = entries[name];
            entry.url = device?.url ?? null;
            entry.value.text = device?.address ?? '—';
            const status = device?.reachable === true ? 'Reachable'
                : device?.reachable === false ? 'No response' : 'Unavailable';
            const mounts = device?.mounts ?? [];
            entry.detail.text = name === 'NAS' && mounts.length ? `${status} · Mounted`
                : name === 'Router' && data?.gateway === device?.address ? `${status} · Gateway` : status;
            const connection = device?.reachable
                ? `Web port reachable · ${device.connectMs.toFixed(1)} ms TCP connect`
                : device ? 'Web port did not respond' : 'Connection information unavailable';
            const more = name === 'NAS' ? (mounts.length
                ? mounts.map(mount => `SMB ${mount.share} · ${mount.path}`).join('\n') : 'No mounted SMB share')
                : `Default gateway: ${data?.gateway ?? 'Unavailable'}`;
            this._tooltips.set(entry.actor, `${name}\n` +
                `${connection}\n${more}\n${entry.url ? `Open ${entry.url}` : 'No device configured'}`);
        }
    }

    _openDirectory(path) {
        this._openUri(Gio.File.new_for_path(path).get_uri());
    }

    _openUri(uri) {
        const state = this._state;
        this._tooltips.hide();
        this._indicator.menu.close();
        Gio.AppInfo.launch_default_for_uri_async(uri,
            global.create_app_launch_context(0, -1), null, (_source, result) => {
                try {
                    Gio.AppInfo.launch_default_for_uri_finish(result);
                } catch (error) {
                    if (state.active)
                        Main.notifyError('Could not open location', error.message);
                }
            });
    }
    async _readSnapshot(state, args) {
        state.busy = true;
        const argv = ['@python@', '-B', `${this.path}/collector.py`, ...args];
        try {
            const process = Gio.Subprocess.new(argv,
                Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_SILENCE);
            state.process = process;
            state.cancellable = new Gio.Cancellable();
            state.timeout = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 5, () => {
                state.timeout = 0;
                process.force_exit();
                return GLib.SOURCE_REMOVE;
            });
            const output = await new Promise((resolve, reject) => {
                process.communicate_utf8_async(null, state.cancellable, (proc, result) => {
                    try {
                        const [, stdout] = proc.communicate_utf8_finish(result);
                        if (!proc.get_successful())
                            throw new Error('Resource collector failed');
                        resolve(stdout);
                    } catch (error) {
                        reject(error);
                    }
                });
            });
            return JSON.parse(output);
        } finally {
            if (state.timeout)
                GLib.Source.remove(state.timeout);
            state.timeout = 0;
            state.process = null;
            state.cancellable = null;
            state.busy = false;
        }
    }

    async _poll(state) {
        if (!state.active || state.busy)
            return;
        const now = GLib.get_monotonic_time();
        const storage = state.storageAt === 0 || now - state.storageAt >= 30_000_000;
        const args = [];
        if (storage)
            args.push('--storage');
        if (this._indicator.menu.isOpen)
            args.push('--applications');
        try {
            const snapshot = await this._readSnapshot(state, args);
            if (!state.active)
                return;
            this._update(snapshot, state);
            if (storage)
                state.storageAt = now;
        } catch (_error) {
            if (state.active) {
                state.previousCpu = null;
                state.storageAt = 0;
                for (const value of Object.values(this._values))
                    value.text = '—';
                this._indicator.accessible_name = 'System Resources: readings unavailable';
                this._clearReadings();
            }
        }
    }

    async _pollNetwork(state) {
        if (!state.active || state.network.busy || !this._indicator.menu.isOpen)
            return;
        const now = GLib.get_monotonic_time();
        if (state.networkAt && now - state.networkAt < 15_000_000)
            return;
        // Device timeouts cannot delay the CPU/memory collection lane.
        state.networkAt = now;
        try {
            const snapshot = await this._readSnapshot(state.network, ['--network']);
            if (state.active)
                this._updateNetwork(snapshot);
        } catch (_error) {
            if (state.active)
                this._updateNetwork(null);
        }
    }

    _update(snapshot, state) {
        const cpu = cpuUsage(state.previousCpu, snapshot.cpu);
        state.previousCpu = snapshot.cpu;
        this._values.CPU.text = percent(cpu);
        this._values.GPU.text = percent(snapshot.gpu?.busy);
        this._values.RAM.text = bytes(snapshot.memory?.used, true);
        this._indicator.accessible_name = `System Resources: CPU ${percent(cpu)}, ` +
            `GPU ${percent(snapshot.gpu?.busy)}, RAM ${bytes(snapshot.memory?.used)}`;
        this._cpu.capacity.update(snapshot.memory);
        this._gpu.capacity.update(snapshot.gpu);
        if (snapshot.storage) {
            const disks = [...snapshot.storage.volatile, ...snapshot.storage.persistent];
            for (const [path, tile] of this._disks)
                tile.update(disks.find(disk => disk.path === path));
        }
        if (snapshot.threads)
            this._updateThreads(snapshot.threads, state);
        if (snapshot.cpuSensors) {
            const cpuSensors = snapshot.cpuSensors;
            sensor(this._cpu.temperature, 'CPU temperature', cpuSensors.temperature,
                {temperature: true, limit: cpuSensors.temperatureLimit});
            sensor(this._cpu.power, 'CPU package power', cpuSensors.power,
                {scale: cpuSensors.powerScale, detail: 'Includes integrated graphics and SoC'});
        }
        const gpu = snapshot.gpu;
        if (gpu && Object.hasOwn(gpu, 'videoBusy')) {
            this._gpu.subtitle.text = gpu.name;
            for (const engine of this._engines)
                engine.update(gpu[engine.key], `${engine.name} · ${percent(gpu[engine.key])}`);
            sensor(this._gpu.temperature, 'GPU temperature (edge)', gpu.temperature,
                {temperature: true, limit: gpu.temperatureLimit});
            sensor(this._gpu.power, 'GPU power', gpu.power, {limit: gpu.powerLimit, scale: gpu.powerLimit});
        } else if (!gpu) {
            this._clearGpu();
        }
        if (snapshot.applications && this._indicator.menu.isOpen) {
            this._renderConsumers(this._cpu.apps, snapshot.applications.items, 'No readable RAM consumers');
            this._renderConsumers(this._gpu.apps, snapshot.applications.vramItems,
                snapshot.applications.vramStatus === 'ok' ? 'No active VRAM consumers' : 'VRAM consumers unavailable');
        }
    }

    _updateThreads(threads, state) {
        const signature = threads.map(t => `${t.package}:${t.core}:${t.id}`).join(',');
        if (signature !== this._coreSignature) {
            this._cpu.grid.destroy_all_children();
            this._cores.clear();
            this._coreSignature = signature;
            const cores = new Map();
            for (const thread of threads) {
                const key = `${thread.package}:${thread.core}`;
                if (!cores.has(key))
                    cores.set(key, []);
                cores.get(key).push(thread);
            }
            let index = 0;
            for (const group of cores.values()) {
                const pair = grid(group.length, 2, true);
                group.forEach((thread, threadIndex) => {
                    const metric = new Metric(this._tooltips, {core: true});
                    metric.name = `Core ${index + 1} · Thread ${threadIndex + 1}`;
                    pair.add(metric.actor, threadIndex);
                    this._cores.set(thread.id, metric);
                });
                this._cpu.grid.add(pair, index++);
            }
            this._cpu.subtitle.text = `${cores.size} cores · ${threads.length} threads`;
        }
        for (const thread of threads) {
            const metric = this._cores.get(thread.id);
            const value = cpuUsage(state.previousThreads.get(thread.id), thread);
            metric.update(value, `${metric.name} · ${percent(value)}`);
        }
        state.previousThreads = new Map(threads.map(thread => [thread.id, thread]));
    }

    _renderConsumers(rows, apps, emptyText) {
        rows.forEach((row, index) => {
            const app = apps[index];
            // Reserve three rows so both cards stay aligned as processes change.
            row.actor.opacity = app || index === 0 ? 255 : 0;
            if (!app) {
                row.name.text = index === 0 ? emptyText : '—';
                row.value.text = '';
                return;
            }
            const desktop = app.desktop && Shell.AppSystem.get_default().lookup_app(app.desktop);
            const localNames = {'org.gnome.Shell@user': 'GNOME Shell',
                'org.chromium.Chromium': 'Chromium', 'codex-desktop': 'Codex'};
            row.name.text = localNames[app.name] ?? desktop?.get_name() ?? app.name;
            row.value.text = `${app.approximate ? '≈ ' : ''}${bytes(app.bytes)}`;
        });
    }

    _clearGpu() {
        for (const engine of this._engines)
            engine.update(null, `${engine.name} · Unavailable`);
        sensor(this._gpu.temperature, 'GPU temperature', null, {temperature: true});
        sensor(this._gpu.power, 'GPU power', null);
    }

    _clearReadings() {
        for (const tile of this._disks.values())
            tile.update(null);
        this._cpu.capacity.update(null);
        this._gpu.capacity.update(null);
        for (const metric of this._cores.values())
            metric.update(null, `${metric.name} · Unavailable`);
        this._state.previousThreads.clear();
        sensor(this._cpu.temperature, 'CPU temperature', null, {temperature: true});
        sensor(this._cpu.power, 'CPU package power', null);
        this._clearGpu();
        this._renderConsumers(this._cpu.apps, [], 'RAM consumers unavailable');
        this._renderConsumers(this._gpu.apps, [], 'VRAM consumers unavailable');
    }

    disable() {
        const state = this._state;
        if (state) {
            state.active = false;
            if (state.timer)
                GLib.Source.remove(state.timer);
            for (const request of [state, state.network]) {
                if (request.timeout)
                    GLib.Source.remove(request.timeout);
                request.timeout = 0;
                request.process?.force_exit();
                request.cancellable?.cancel();
            }
        }
        // Destroy sources before their shared tooltip (source destroy hides it).
        this._indicator?.destroy();
        this._tooltips?.destroy();
        this._indicator = this._tooltips = this._content = this._state = null;
        this._disks = this._cores = this._engines = this._values = null;
        this._cpu = this._gpu = this._resources = this._storage = null;
        this._network = null;
    }
}
