import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';
import Pango from 'gi://Pango';
import St from 'gi://St';

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {BarLevel} from 'resource:///org/gnome/shell/ui/barLevel.js';
import {bytes, level, percent, rangeText, thermalEdges} from './format.js';

export function label(text, params = {}) {
    const actor = new St.Label({text, y_align: Clutter.ActorAlign.CENTER, ...params});
    if (params.style_class?.split(' ').includes('sr-muted'))
        actor.opacity = 178;
    actor.clutter_text.ellipsize = Pango.EllipsizeMode.END;
    return actor;
}

export function box(vertical = false, style = '', params = {}) {
    return new St.BoxLayout({orientation: vertical ? Clutter.Orientation.VERTICAL : Clutter.Orientation.HORIZONTAL,
        style_class: style, ...params});
}

export function grid(columns, gap = 10, equalRows = false) {
    const layout = new Clutter.GridLayout({column_homogeneous: true, row_homogeneous: equalRows});
    const actor = new St.Widget({layout_manager: layout, x_expand: true, y_expand: true});
    actor.connect('style-changed', () => {
        const scale = St.ThemeContext.get_for_stage(global.stage).scale_factor;
        layout.column_spacing = gap * scale;
        layout.row_spacing = gap * scale;
    });
    actor.add = (child, index, span = 1) => layout.attach(child, index % columns, Math.floor(index / columns), span, 1);
    return actor;
}

// One tooltip for the whole menu. Sources own their signal connections, and the
// extension owns this actor/timer; nothing survives disable or a closed menu.
export class Tooltips {
    constructor() {
        this.actor = label('', {style_class: 'screenshot-ui-tooltip', visible: false});
        Main.layoutManager.addTopChrome(this.actor);
        this._timer = 0;
    }

    bind(source) {
        source.reactive = true;
        source.track_hover = true;
        source.can_focus = true;
        source.connect('notify::hover', () => source.hover ? this.show(source) : this.hide(source));
        source.connect('key-focus-in', () => this.show(source));
        source.connect('key-focus-out', () => this.hide(source));
        source.connect('destroy', () => this.hide(source));
    }

    set(source, text) {
        source.resourceTooltip = text;
        source.accessible_name = text.replaceAll('\n', ', ');
        if (source === this._source && this.actor.visible) {
            this.actor.text = text;
            this._position();
        }
    }

    show(source) {
        this.hide();
        this._source = source;
        this._timer = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 400, () => {
            this._timer = 0;
            if (source.mapped && source.resourceTooltip) {
                this.actor.text = source.resourceTooltip;
                this.actor.show();
                // The popup is added to uiGroup after this tooltip is created.
                // Raise on every show, including after reopening the menu.
                this.actor.get_parent()?.set_child_above_sibling(this.actor, null);
                this._position();
            }
            return GLib.SOURCE_REMOVE;
        });
    }

    _position() {
        const source = this._source;
        if (!source)
            return;
        const monitor = Main.layoutManager.findMonitorForActor(source) ?? Main.layoutManager.primaryMonitor;
        const [x, y] = source.get_transformed_position();
        const [width, height] = source.get_transformed_size();
        const [, tw] = this.actor.get_preferred_width(-1);
        const [, th] = this.actor.get_preferred_height(tw);
        const gap = 8 * St.ThemeContext.get_for_stage(global.stage).scale_factor;
        const tx = Math.max(monitor.x + gap, Math.min(x + (width - tw) / 2,
            monitor.x + monitor.width - tw - gap));
        let ty = y - th - gap;
        if (ty < monitor.y + gap)
            ty = y + height + gap;
        ty = Math.max(monitor.y + gap, Math.min(ty, monitor.y + monitor.height - th - gap));
        this.actor.set_position(Math.round(tx), Math.round(ty));
    }

    hide(source = null) {
        if (source && source !== this._source)
            return;
        if (this._timer)
            GLib.Source.remove(this._timer);
        this._timer = 0;
        this._source = null;
        this.actor.hide();
    }

    destroy() {
        this.hide();
        this.actor.destroy();
    }
}

function rgba(color) {
    return [color.red, color.green, color.blue, color.alpha].map(value => value / 255);
}

function blend(a, b, weight) {
    return a.map((value, i) => value * (1 - weight) + b[i] * weight);
}

function roundedRect(cr, width, height, radius) {
    const r = Math.min(radius, width / 2, height / 2);
    cr.newSubPath();
    cr.arc(width - r, r, r, -Math.PI / 2, 0);
    cr.arc(width - r, height - r, r, 0, Math.PI / 2);
    cr.arc(r, height - r, r, Math.PI / 2, Math.PI);
    cr.arc(r, r, r, Math.PI, Math.PI * 1.5);
    cr.closePath();
}

// A common theme-derived scale for the mosaic, activity tiles and sensor rings.
// Drawing areas inherit slider colors; style changes repaint from the new theme.
export class Metric {
    constructor(tooltips, {icon = null, gicon = null, ring = false, core = false} = {}) {
        this._tooltips = tooltips;
        this._ring = ring;
        this._core = core;
        this.band = null;
        this.actor = new St.Widget({layout_manager: new Clutter.BinLayout(),
            style_class: ring ? 'sr-gauge' : 'sr-metric', x_expand: !ring, y_expand: !ring,
            x_align: ring ? Clutter.ActorAlign.CENTER : Clutter.ActorAlign.FILL});
        this.canvas = new St.DrawingArea({style_class: 'slider sr-drawing', x_expand: true, y_expand: true});
        this.actor.add_child(this.canvas);
        if (icon || gicon) {
            this.icon = new St.Icon({...gicon ? {gicon} : {icon_name: icon}, style_class: 'sr-metric-icon',
                x_align: Clutter.ActorAlign.CENTER, y_align: Clutter.ActorAlign.CENTER});
            this.actor.add_child(this.icon);
        }
        this.canvas.connect('repaint', () => this._draw());
        this.canvas.connect('style-changed', () => this.canvas.queue_repaint());
        this.actor.connect('notify::allocation', () => this.canvas.queue_repaint());
        tooltips.bind(this.actor);
    }

    update(value, tooltip, edges = [20, 40, 60, 80]) {
        const band = level(value, edges);
        this._tooltips.set(this.actor, tooltip);
        if (this.icon) {
            this.icon.opacity = band === null ? 100 : 255;
        }
        if (this.band !== band) {
            this.band = band;
            this.canvas.queue_repaint();
        }
    }

    _draw() {
        const cr = this.canvas.get_context();
        const [width, height] = this.canvas.get_surface_size();
        const node = this.canvas.get_theme_node();
        const foreground = rgba(node.get_foreground_color());
        const [hasAccent, accentColor] = node.lookup_color('-barlevel-active-background-color', false);
        const [hasTrack, trackColor] = node.lookup_color('-barlevel-background-color', false);
        if (this.icon) {
            const [hasInk, ink] = node.lookup_color('-barlevel-active-foreground-color', false);
            const inkCss = hasInk ? `rgb(${ink.red}, ${ink.green}, ${ink.blue})` : '-st-accent-fg-color';
            this.icon.set_style(!this._ring && this.band >= 2
                ? `color: ${inkCss};` : null);
        }
        const accent = hasAccent ? rgba(accentColor) : foreground;
        const track = hasTrack ? rgba(trackColor) : [...foreground.slice(0, 3), 0.12];
        const neutral = [...foreground.slice(0, 3), 0.24];
        this.color = this.band === null ? track : blend(neutral, accent, this.band / 4);
        const scale = St.ThemeContext.get_for_stage(global.stage).scale_factor;
        if (this._ring) {
            const radius = Math.min(width, height) / 2 - 4 * scale;
            cr.setLineWidth(3.5 * scale);
            cr.setSourceRGBA(...track);
            cr.arc(width / 2, height / 2, radius, 0, Math.PI * 2);
            cr.stroke();
            if (this.band !== null) {
                cr.setSourceRGBA(...this.color);
                cr.arc(width / 2, height / 2, radius, -Math.PI / 2,
                    -Math.PI / 2 + (this.band + 1) / 5 * Math.PI * 2);
                cr.stroke();
            }
        } else {
            roundedRect(cr, width, height, (this._core ? 3 : 9) * scale);
            cr.setSourceRGBA(...this.color);
            cr.fill();
        }
        cr.$dispose();
    }
}

export class Capacity {
    constructor(name, tooltips, {path = null, open = null} = {}) {
        this.name = name;
        this.path = path;
        this._tooltips = tooltips;
        this.actor = path ? new St.Button({style_class: 'quick-toggle-menu sr-storage',
            x_expand: true, y_expand: true, can_focus: true}) : box(true, 'sr-capacity');
        const stack = path ? box(true, 'sr-storage-content') : this.actor;
        const line = path ? stack : box(false, 'sr-capacity-line');
        this.title = label(name, {x_expand: true, style_class: path ? 'sr-storage-name' : 'sr-capacity-name'});
        this.value = label('—', {style_class: 'system-resources-value sr-muted sr-capacity-value',
            x_align: path ? Clutter.ActorAlign.START : Clutter.ActorAlign.END});
        line.add_child(this.title);
        line.add_child(this.value);
        if (!path)
            stack.add_child(line);
        this.bar = new BarLevel({style_class: 'slider sr-bar', x_expand: true});
        stack.add_child(this.bar);
        if (path) {
            this.actor.set_child(stack);
            this.actor.connect('clicked', () => open(path));
        }
        tooltips.bind(this.actor);
        this.update(null);
    }

    update(data) {
        const valid = data && Number.isFinite(data.total) && data.total > 0 && Number.isFinite(data.used);
        const unavailable = data?.status === 'unmounted' ? 'Not mounted' : 'Unavailable';
        this.value.text = valid ? bytes(data.total) : '—';
        const fraction = data?.fraction ?? (valid ? data.used / data.total : null);
        this.bar.value = valid ? Math.min(1, Math.max(0, fraction)) : 0;
        this.bar.opacity = valid ? 255 : 80;
        const available = data?.available ?? (valid ? Math.max(0, data.total - data.used) : null);
        this._tooltips.set(this.actor, valid
            ? `${this.name} · ${bytes(available)} available${this.path ? `\n${this.path}` : ''}`
            : `${this.name} · ${unavailable}${this.path ? `\n${this.path}` : ''}`);
        // Screen readers retain the utilization omitted from the visual labels.
        this.actor.accessible_name = valid
            ? `${this.name}: ${percent(fraction * 100)} used, ${bytes(data.total)} total, ${bytes(available)} available`
            : `${this.name}: ${unavailable}`;
        this.bar.accessible_name = this.actor.accessible_name;
    }
}

export function sensor(metric, name, value, {temperature = false, limit = null, scale = null, detail = ''} = {}) {
    const edges = temperature ? thermalEdges(limit) : scale > 0 ? [0.2, 0.4, 0.6, 0.8].map(x => x * scale) : null;
    const unit = temperature ? '°C' : 'W';
    const text = Number.isFinite(value) ? `${name} · ${value.toFixed(1)} ${unit}` : `${name} · Unavailable`;
    const range = edges && Number.isFinite(value) ? `\n${rangeText(value, edges, unit)}` : '';
    const reference = Number.isFinite(limit) ? `\n${temperature ? 'Temperature limit' : 'Power limit'}: ${limit} ${unit}`
        : scale > 0 ? `\nScale: 0–${scale} ${unit}` : '';
    metric.update(edges ? value : null, text + range + reference + (detail ? `\n${detail}` : ''), edges ?? []);
}
