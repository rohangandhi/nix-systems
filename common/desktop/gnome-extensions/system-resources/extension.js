import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Pango from 'gi://Pango';
import Shell from 'gi://Shell';
import St from 'gi://St';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import {BarLevel} from 'resource:///org/gnome/shell/ui/barLevel.js';

import {bytes, capacity, cpuUsage, percent} from './format.js';

function label(text, params = {}) {
    return new St.Label({text, y_align: Clutter.ActorAlign.CENTER, ...params});
}

function row(section, name, withBar = false) {
    const item = new PopupMenu.PopupBaseMenuItem({
        reactive: false, can_focus: true, style_class: 'system-resources-row',
    });
    const stack = new St.BoxLayout({orientation: Clutter.Orientation.VERTICAL,
        x_expand: true, style_class: 'system-resources-stack'});
    const line = new St.BoxLayout({style_class: 'system-resources-line'});
    const title = label(name, {x_expand: true});
    title.clutter_text.ellipsize = Pango.EllipsizeMode.END;
    const value = label('—', {x_align: Clutter.ActorAlign.END, style_class: 'system-resources-value'});
    line.add_child(title);
    line.add_child(value);
    stack.add_child(line);
    const bar = withBar ? new BarLevel({style_class: 'slider system-resources-bar'}) : null;
    if (bar)
        stack.add_child(bar);
    item.add_child(stack);
    section.addMenuItem(item);
    return {item, title, value, bar};
}

function setRow(target, text, fraction = null) {
    target.value.text = text;
    target.item.accessible_name = `${target.title.text}: ${text}`;
    if (target.bar) {
        target.bar.visible = Number.isFinite(fraction);
        target.bar.value = Number.isFinite(fraction) ? Math.max(0, Math.min(1, fraction)) : 0;
        target.bar.overdriveStart = fraction >= 0.9 ? 0.9 : 1;
        target.bar.accessible_name = target.item.accessible_name;
    }
}

function heading(section, text, first = false) {
    if (!first)
        section.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
    const item = new PopupMenu.PopupMenuItem(text, {reactive: false, can_focus: false});
    item.add_style_class_name('system-resources-heading');
    section.addMenuItem(item);
}

export default class SystemResources extends Extension {
    enable() {
        // Keep async callbacks tied to this enable cycle, even across re-enables.
        const state = {active: true, busy: false, process: null, timeout: 0,
            cancellable: null, previousCpu: null, storageAt: 0, timer: 0};
        this._state = state;
        this._consumerMode = 'ram';
        this._applications = null;
        this._indicator = new PanelMenu.Button(0, 'System Resources');
        const panel = new St.BoxLayout({style_class: 'system-resources-panel'});
        this._values = {};
        for (const name of ['CPU', 'GPU', 'RAM']) {
            const value = label('—', {style_class: `system-resources-value ${name === 'RAM'
                ? 'system-resources-memory' : 'system-resources-percent'}`, accessible_name: name});
            panel.add_child(value);
            this._values[name] = value;
        }
        this._indicator.add_child(panel);
        this._buildMenu();
        // Register first: our focus handler must run after the panel's modal grab.
        Main.panel.addToStatusArea(this.uuid, this._indicator, 0, 'right');
        this._indicator.menu.connect('open-state-changed', (_menu, open) => {
            if (open) {
                // Constrain to the current monitor at its actual text/UI scale.
                const monitor = Main.layoutManager.findMonitorForActor(this._indicator);
                const scale = St.ThemeContext.get_for_stage(global.stage).scale_factor;
                this._scroll.set_style(`max-height: ${Math.max(160, Math.min(560,
                    (monitor.height - Main.panel.height - 80) / scale))}px;`);
                this._scroll.grab_key_focus();
                void this._poll(state);
            }
        });
        void this._poll(state);
        state.timer = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 2, () => {
            void this._poll(state);
            return GLib.SOURCE_CONTINUE;
        });
    }

    _buildMenu() {
        this._scroll = new St.ScrollView({style_class: 'system-resources-scroll vfade',
            reactive: true, can_focus: true,
            overlay_scrollbars: true, hscrollbar_policy: St.PolicyType.NEVER,
            vscrollbar_policy: St.PolicyType.AUTOMATIC});
        this._scroll.connect('key-press-event', (_actor, event) => {
            const adjustment = this._scroll.vadjustment;
            const key = event.get_key_symbol();
            const step = adjustment.step_increment || 32;
            const offsets = new Map([[Clutter.KEY_Up, -step], [Clutter.KEY_Down, step],
                [Clutter.KEY_Page_Up, -adjustment.page_size],
                [Clutter.KEY_Page_Down, adjustment.page_size],
                [Clutter.KEY_Home, -adjustment.upper], [Clutter.KEY_End, adjustment.upper]]);
            if (!offsets.has(key))
                return Clutter.EVENT_PROPAGATE;
            adjustment.value = Math.max(adjustment.lower, Math.min(
                adjustment.upper - adjustment.page_size, adjustment.value + offsets.get(key)));
            return Clutter.EVENT_STOP;
        });
        this._content = new PopupMenu.PopupMenuSection();
        this._content.actor.add_style_class_name('system-resources-content');
        // Add via the menu first so item signals and section lifetime are managed.
        this._indicator.menu.addMenuItem(this._content);
        this._indicator.menu.box.remove_child(this._content.actor);
        this._scroll.set_child(this._content.actor);
        this._indicator.menu.box.add_child(this._scroll);

        heading(this._content, 'Persistent Storage', true);
        this._disks = new Map();
        for (const path of ['/p-os', '/p-home', '/p-data', '/p-shared'])
            this._disks.set(path, row(this._content, path.slice(1), true));

        heading(this._content, 'Volatile Storage');
        this._volatileSection = new PopupMenu.PopupMenuSection();
        this._content.addMenuItem(this._volatileSection);
        this._volatileRows = new Map();

        heading(this._content, 'Memory');
        this._ram = row(this._content, 'RAM', true);
        this._vram = row(this._content, 'VRAM', true);

        const selector = new PopupMenu.PopupBaseMenuItem({reactive: false, can_focus: false});
        selector.add_child(label('Largest consumers', {x_expand: true}));
        this._sortButtons = {};
        for (const mode of ['ram', 'vram']) {
            const button = new St.Button({label: mode.toUpperCase(), can_focus: true,
                toggle_mode: true, checked: mode === 'ram',
                accessible_name: `Show largest ${mode.toUpperCase()} consumers`,
                style_class: 'button system-resources-sort'});
            button.connect('clicked', () => {
                this._consumerMode = mode;
                this._renderConsumers();
            });
            this._sortButtons[mode] = button;
            selector.add_child(button);
        }
        this._content.addMenuItem(selector);
        this._apps = Array.from({length: 5}, () => row(this._content, '…'));
        this._appNote = new PopupMenu.PopupMenuItem('Your apps and services · shared memory apportioned',
            {reactive: false, can_focus: false});
        this._appNote.add_style_class_name('system-resources-note');
        this._appNote.label.clutter_text.line_wrap = true;
        this._appNote.label.clutter_text.ellipsize = Pango.EllipsizeMode.NONE;
        this._content.addMenuItem(this._appNote);
    }

    async _poll(state) {
        if (!state.active || state.busy)
            return;
        state.busy = true;
        const now = GLib.get_monotonic_time();
        const storage = state.storageAt === 0 || now - state.storageAt >= 30_000_000;
        const applications = this._indicator.menu.isOpen;
        const argv = ['@python@', '-B', `${this.path}/collector.py`];
        if (storage)
            argv.push('--storage');
        if (applications)
            argv.push('--applications');
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
            if (!state.active)
                return;
            const snapshot = JSON.parse(output);
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
                this._applications = null;
                for (const target of [...this._disks.values(), ...this._volatileRows.values(),
                    this._ram, this._vram, ...this._apps])
                    setRow(target, 'Unavailable');
            }
        } finally {
            if (state.timeout)
                GLib.Source.remove(state.timeout);
            state.timeout = 0;
            state.process = null;
            state.cancellable = null;
            state.busy = false;
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

        const memory = snapshot.memory;
        setRow(this._ram, memory ? capacity(memory.used, memory.total) : 'Unavailable',
            memory?.total > 0 ? memory.used / memory.total : null);
        if (memory)
            this._ram.item.accessible_name += `, ${bytes(memory.available)} available`;
        const gpu = snapshot.gpu;
        setRow(this._vram, Number.isFinite(gpu?.used)
            ? capacity(gpu.used, gpu.total) : 'Unavailable',
            Number.isFinite(gpu?.used) && gpu.total > 0 ? gpu.used / gpu.total : null);

        if (snapshot.storage) {
            for (const disk of snapshot.storage.persistent)
                this._updateFilesystem(this._disks.get(disk.path), disk);
            const paths = new Set(snapshot.storage.volatile.map(item => item.path));
            for (const [path, target] of this._volatileRows) {
                if (!paths.has(path)) {
                    target.item.destroy();
                    this._volatileRows.delete(path);
                }
            }
            for (const disk of snapshot.storage.volatile) {
                if (!this._volatileRows.has(disk.path))
                    this._volatileRows.set(disk.path, row(this._volatileSection, disk.name, true));
                this._updateFilesystem(this._volatileRows.get(disk.path), disk);
            }
        }

        if (snapshot.applications && this._indicator.menu.isOpen) {
            this._applications = snapshot.applications;
            this._renderConsumers();
        }
    }

    _renderConsumers() {
        const vram = this._consumerMode === 'vram';
        for (const [mode, button] of Object.entries(this._sortButtons))
            button.checked = mode === this._consumerMode;
        if (!this._applications) {
            for (const target of this._apps)
                target.item.hide();
            this._appNote.label.text = 'Waiting for application readings';
            return;
        }
        const apps = vram ? this._applications.vramItems : this._applications.items;
        this._apps.forEach((target, index) => {
            const app = apps[index];
            target.item.visible = Boolean(app);
            if (!app)
                return;
            const desktop = app.desktop && Shell.AppSystem.get_default().lookup_app(app.desktop);
            const localNames = {'org.gnome.Shell@user': 'GNOME Shell',
                'org.chromium.Chromium': 'Chromium', 'codex-desktop': 'Codex'};
            target.title.text = localNames[app.name] ?? desktop?.get_name() ?? app.name;
            setRow(target, `${app.approximate ? '≈ ' : ''}${bytes(app.bytes)}`);
        });
        this._appNote.label.text = vram
            ? 'Reported VRAM · shared GPU buffers may overlap'
            : apps.some(app => app.approximate)
                ? 'Your apps and services · ≈ estimated shared memory'
                : 'Your apps and services · shared memory apportioned';
        if (!vram && this._applications.omitted)
            this._appNote.label.text += '\nSome processes could not be read';
        if (apps.length === 0)
            this._appNote.label.text = vram
                ? this._applications.vramStatus === 'ok'
                    ? 'No active VRAM consumers' : 'VRAM consumers unavailable'
                : 'No readable application memory';
    }

    _updateFilesystem(target, disk) {
        if (disk.status !== 'ok') {
            setRow(target, disk.status === 'unmounted' ? 'Not mounted' : 'Unavailable');
            return;
        }
        setRow(target, capacity(disk.used, disk.total), disk.fraction);
        target.item.accessible_name += `, ${bytes(disk.available)} available`;
    }

    disable() {
        const state = this._state;
        if (state) {
            state.active = false;
            if (state.timer)
                GLib.Source.remove(state.timer);
            if (state.timeout)
                GLib.Source.remove(state.timeout);
            state.timeout = 0;
            state.process?.force_exit();
            state.cancellable?.cancel();
        }
        // The section is wrapped in a scroll view, outside menu.removeAll().
        this._content?.destroy();
        this._indicator?.destroy();
        this._indicator = null;
        this._state = null;
        this._content = null;
        this._scroll = null;
        this._values = null;
        this._disks = null;
        this._volatileRows = null;
        this._volatileSection = null;
        this._apps = null;
        this._appNote = null;
        this._sortButtons = this._applications = null;
        this._ram = this._vram = null;
    }
}
