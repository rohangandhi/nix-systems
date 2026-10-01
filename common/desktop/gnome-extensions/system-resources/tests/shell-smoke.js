// Run only in the isolated session created by run-shell-test.py.
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Shell from 'gi://Shell';
import St from 'gi://St';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as Scripting from 'resource:///org/gnome/shell/ui/scripting.js';

function assert(condition, message) {
    if (!condition)
        throw new Error(message);
}

function near(a, b, message) {
    assert(Math.abs(a - b) <= 1, `${message}: ${a} != ${b}`);
}

function bounds(actor) {
    const [x, y] = actor.get_transformed_position();
    const [width, height] = actor.get_transformed_size();
    return {x, y, width, height, cx: x + width / 2, cy: y + height / 2};
}

async function capture(name) {
    const path = GLib.build_filenamev([GLib.getenv('SYSTEM_RESOURCES_TEST_OUTPUT'), `${name}.png`]);
    const stream = Gio.File.new_for_path(path).replace(null, false, Gio.FileCreateFlags.NONE, null);
    await new Shell.Screenshot().screenshot(false, stream);
    stream.close(null);
}

export async function run() {
    await Scripting.sleep(4000);
    Main.overview.hide();
    const extension = Main.extensionManager.lookup('system-resources@local');
    assert(extension?.state === 1, `Extension failed to enable: ${extension?.errors}`);
    const instance = extension.stateObj;
    assert(instance._values.RAM.text !== '—', 'RAM sampling failed');
    assert(instance._values.CPU.text !== '—', 'CPU sampling failed');
    assert(instance._values.CPU.get_parent().get_n_children() === 3, 'Panel has more than three values');
    for (const [name, value] of Object.entries(instance._values)) {
        assert(!value.text.includes(name), `Panel still labels ${name}`);
        assert(value.get_theme_node().get_font().get_family() === 'NotoSansM Nerd Font Mono',
            'Numeric values do not use the configured Nerd font');
    }
    instance._indicator.menu.open();
    await Scripting.sleep(4500);
    const tiles = [...instance._disks.values()];
    assert(tiles.map(t => t.name).join(',') === 'Root,Home,P-Home,P-Data,P-Shared,P-OS', 'Wrong storage order');
    assert(tiles.every(t => t.value.text !== '—'), 'Missing disk readings');
    assert(instance._cores.size === 24, 'Expected this host’s 24 threads');
    assert([...instance._cores.values()].every(t => t.band !== null), 'Per-thread sampling failed');
    assert(instance._cpu.apps.length === 3 && instance._gpu.apps.length === 3, 'Expected three consumers per card');
    assert(instance._cpu.apps[0].value.text, 'Missing RAM consumers');
    for (const tile of tiles) {
        assert(!tile.value.text.includes('/') && !tile.value.text.includes('%'), 'Storage still shows used / percent');
        assert(!tile.actor.resourceTooltip.match(/\d+ B\b/), 'Tooltip contains raw bytes');
        near(tile.actor.width, tiles[0].actor.width, 'Storage widths differ');
        near(bounds(tile.actor).y, bounds(tiles[0].actor).y, 'Storage rows differ');
        assert(!tile.value.clutter_text.get_layout().is_ellipsized(), 'Storage capacity is truncated');
    }
    const cpu = instance._cpu;
    const gpu = instance._gpu;
    const networkFixture = {dns: ['192.0.2.53'], interface: 'eno1',
        nas: {address: '192.0.2.10', url: 'https://192.0.2.10', reachable: true, connectMs: 1, mounts: []},
        router: {address: '198.51.100.20', url: 'https://198.51.100.20/', reachable: true, connectMs: 1}};
    instance._updateNetwork(networkFixture);
    const network = instance._network;
    assert(network.entries.DNS.value.text !== '—', 'DNS was not collected');
    assert(network.entries.NAS.value.text === '192.0.2.10', 'NAS address missing');
    assert(network.entries.Router.value.text === '198.51.100.20', 'Router address missing');
    assert(network.subtitle.text.includes('eno1'), 'Active interface missing');
    assert(bounds(network.actor).y >= bounds(cpu.actor).y + cpu.actor.height, 'Network overlaps CPU/GPU');
    near(bounds(network.actor).x, bounds(cpu.actor).x, 'Network left edge differs');
    near(bounds(network.actor).x + network.actor.width, bounds(gpu.actor).x + gpu.actor.width,
        'Network right edge differs');
    const networkEntries = Object.values(network.entries);
    for (const entry of networkEntries) {
        near(entry.actor.width, networkEntries[0].actor.width, 'Network columns differ');
        assert(!entry.value.clutter_text.get_layout().is_ellipsized(), 'Network address truncated');
        assert(!entry.detail.clutter_text.get_layout().is_ellipsized(), 'Network detail truncated');
        near(bounds(entry.value).x - bounds(entry.actor).x,
            bounds(networkEntries[0].value).x - bounds(networkEntries[0].actor).x,
            'Network column content padding differs');
    }
    near(cpu.actor.width, gpu.actor.width, 'Card widths differ');
    near(cpu.actor.height, gpu.actor.height, 'Card heights differ');
    near(bounds(cpu.capacity.actor).y, bounds(gpu.capacity.actor).y, 'Memory sections differ');
    near(bounds(cpu.temperature.actor).y, bounds(gpu.temperature.actor).y, 'Temperatures differ');
    near(bounds(cpu.power.actor).y, bounds(gpu.power.actor).y, 'Power positions differ');
    near(cpu.grid.width, gpu.grid.width, 'CPU/GPU activity columns differ');
    for (const card of [cpu, gpu]) {
        for (const metric of [card.temperature, card.power]) {
            near(bounds(metric.actor).cx, bounds(metric.icon).cx, 'Gauge icon is off center horizontally');
            near(bounds(metric.actor).cy, bounds(metric.icon).cy, 'Gauge icon is off center vertically');
            near(metric.actor.width, metric.actor.height, 'Gauge is not square');
            assert(metric.band !== null, 'Sensor unavailable');
        }
        assert(!(card.capacity.actor instanceof St.Button), 'Memory should not be a button');
        assert(card.apps.every(row => !row.actor.resourceTooltip), 'Consumers have tooltips');
        assert(card.apps.every(row => row.name.opacity < row.value.opacity), 'Consumer names are not muted');
    }
    const menu = bounds(instance._indicator.menu.actor);
    assert(menu.y >= 0 && menu.y + menu.height <= global.stage.height, 'Menu exceeds screen height');
    assert(!instance._scroll, 'Menu still uses a scroll view');
    assert(global.stage.get_key_focus() === tiles[0].actor, 'Menu did not receive keyboard focus');
    const radius = instance._indicator.menu.box.get_theme_node().get_border_radius(St.Corner.TOPLEFT);
    const quickRadius = Main.panel.statusArea.quickSettings.menu.box.get_theme_node().get_border_radius(St.Corner.TOPLEFT);
    near(radius, quickRadius, 'Popup corners do not match Quick Settings');
    instance._tooltips.hide();
    await capture('menu');

    // Native palette changes must also repaint the custom indicators.
    const settings = new Gio.Settings({schema_id: 'org.gnome.desktop.interface'});
    const originalAccent = settings.get_string('accent-color');
    instance._engines[0].update(100, 'Graphics activity · 100%');
    await Scripting.sleep(150);
    const firstColor = [...instance._engines[0].color];
    settings.set_string('accent-color', originalAccent === 'purple' ? 'green' : 'purple');
    await Scripting.sleep(700);
    instance._engines[0].update(100, 'Graphics activity · 100%');
    await Scripting.sleep(150);
    assert(firstColor.some((c, i) => Math.abs(c - instance._engines[0].color[i]) > 0.05),
        'Custom indicators did not follow the new accent');
    await capture('menu-accent');
    settings.set_string('accent-color', originalAccent);

    const originalScheme = settings.get_string('color-scheme');
    const darkColor = instance._indicator.menu.box.get_theme_node().get_background_color();
    settings.set_string('color-scheme', 'prefer-light');
    await Scripting.sleep(700);
    const lightColor = instance._indicator.menu.box.get_theme_node().get_background_color();
    assert(lightColor.red !== darkColor.red, 'Popup did not follow the light Shell theme');
    await capture('menu-light');
    const accessibility = new Gio.Settings({schema_id: 'org.gnome.desktop.a11y.interface'});
    accessibility.set_boolean('high-contrast', true);
    await Scripting.sleep(700);
    await capture('menu-high-contrast');
    accessibility.set_boolean('high-contrast', false);
    settings.set_string('color-scheme', originalScheme);
    await Scripting.sleep(400);

    // Exercise the real User Themes loader, palette changes, then unload it.
    // Compare computed widget colors, so a successful Sass build alone cannot
    // hide a missing theme, wrong selector, or stale Cairo indicator color.
    const themes = JSON.parse(GLib.getenv('SYSTEM_RESOURCES_TEST_THEMES') || '[]');
    if (themes.length) {
        const themeUuid = 'user-theme@gnome-shell-extensions.gcampax.github.com';
        const nativeSurface = instance._indicator.menu.box.get_theme_node().get_background_color().to_string();
        const nativeAccent = tiles[0].bar.get_theme_node().get_color('-barlevel-active-background-color').to_string();
        Main.extensionManager.enableExtension(themeUuid);
        await Scripting.sleep(500);
        const themeExtension = Main.extensionManager.lookup(themeUuid);
        assert(themeExtension?.state === 1, `User Themes failed: ${themeExtension?.errors}`);
        const themeSettings = themeExtension.stateObj.getSettings();
        const color = (actual, hex, message) => {
            const rgb = hex.replace(/^#/, '').match(/../g).map(value => parseInt(value, 16));
            assert(actual.red === rgb[0] && actual.green === rgb[1] && actual.blue === rgb[2]
                && actual.alpha === 255, `${message}: ${actual.to_string()} != ${hex}`);
        };
        for (const theme of themes) {
            themeSettings.set_string('name', theme.name);
            await Scripting.sleep(700);
            const c = theme.colors;
            color(Main.panel.get_theme_node().get_background_color(), c.background, 'Panel background');
            color(instance._indicator.menu.box.get_theme_node().get_background_color(), c.surface, 'Resource popup');
            color(Main.panel.statusArea.quickSettings.menu.box.get_theme_node().get_background_color(), c.surface, 'Quick Settings');
            color(instance._values.RAM.get_theme_node().get_foreground_color(), c.foreground, 'Panel text');
            color(tiles[0].bar.get_theme_node().get_color('-barlevel-active-background-color'), c.accent, 'Usage bar');
            const metric = instance._engines[0];
            metric.update(100, 'Graphics activity · 100%');
            await Scripting.sleep(150);
            color(metric.icon.get_theme_node().get_foreground_color(), c.background,
                `Active metric icon (band ${metric.band}, style ${metric.icon.get_style()}, drawn ${metric.color})`);
            const expected = c.accent.replace(/^#/, '').match(/../g).map(value => parseInt(value, 16) / 255);
            assert(expected.every((value, i) => Math.abs(metric.color[i] - value) < 0.001), 'Drawing kept the old accent');
            near(instance._indicator.menu.box.get_theme_node().get_border_radius(St.Corner.TOPLEFT), radius,
                'Palette changed native corners');
            await capture(theme.name);
        }
        themeSettings.set_string('name', '');
        Main.extensionManager.disableExtension(themeUuid);
        await Scripting.sleep(500);
        assert(instance._indicator.menu.box.get_theme_node().get_background_color().to_string() === nativeSurface,
            'Disabling the palette did not restore native surfaces');
        assert(tiles[0].bar.get_theme_node().get_color('-barlevel-active-background-color').to_string() === nativeAccent,
            'Disabling the palette did not restore the native accent');
        await capture('native-restored');
    }

    instance._tooltips.show(cpu.power.actor);
    await Scripting.sleep(500);
    const tooltip = instance._tooltips.actor;
    assert(tooltip.visible, 'Sensor tooltip is missing');
    assert(bounds(tooltip).y + tooltip.height < bounds(cpu.power.actor).y, 'Tooltip is not above source');
    const parent = tooltip.get_parent();
    let popup = instance._indicator.menu.actor;
    while (popup.get_parent() && popup.get_parent() !== parent)
        popup = popup.get_parent();
    assert(popup.get_parent() === parent && parent.get_children().indexOf(tooltip) >
        parent.get_children().indexOf(popup), 'Tooltip is behind the popup');
    await capture('menu-tooltip');
    // Exercise the actual click-to-URI path without launching Files in this test.
    const launch = Gio.AppInfo.launch_default_for_uri_async;
    let uri = null;
    Gio.AppInfo.launch_default_for_uri_async = value => { uri = value; };
    try {
        instance._updateNetwork(networkFixture);
        network.entries.NAS.actor.emit('clicked', 1);
        assert(uri === 'https://192.0.2.10', 'NAS did not open its web interface');
        instance._indicator.menu.open();
        network.entries.Router.actor.emit('clicked', 1);
        assert(uri === 'https://198.51.100.20/', 'Router did not open its web interface');
        instance._indicator.menu.open();
        tiles[0].actor.emit('clicked', 1);
    } finally {
        Gio.AppInfo.launch_default_for_uri_async = launch;
    }
    assert(uri === 'file:///', `Storage did not open the directory URI: ${uri}`);
    assert(!instance._indicator.menu.isOpen && !instance._tooltips.actor.visible, 'Tooltip survives closing');
    const lastNetworkAt = instance._state.networkAt;
    await instance._pollNetwork(instance._state);
    assert(instance._state.networkAt === lastNetworkAt, 'Network probes ran with the menu closed');
    instance._updateNetwork({dns: [], nas: {address: '192.0.2.10', reachable: false, mounts: []},
        router: {address: '198.51.100.20', reachable: false}});
    assert(network.entries.DNS.value.text === '—', 'Old DNS survived disconnect');
    assert(network.entries.NAS.detail.text === 'No response', 'Unreachable NAS reported as available');

    instance._clearReadings();
    assert(cpu.capacity.value.text === '—' && gpu.capacity.value.text === '—',
        'Missing readings were reported as zero');
    assert([...instance._cores.values()].every(t => t.band === null), 'Missing CPU readings stayed live');

    // Disable with a request in flight; old callbacks must not affect a new cycle.
    for (let retry = 0; instance._state.busy && retry < 20; retry++)
        await Scripting.sleep(100);
    const oldState = instance._state;
    const oldTooltip = instance._tooltips;
    instance._indicator.menu.open();
    // Let Shell allocate the opened popup before destroying it; opening and
    // destroying a BoxPointer in the same frame leaves a Shell relayout pending.
    await Scripting.sleep(250);
    for (let retry = 0; (oldState.busy || oldState.network.busy) && retry < 20; retry++)
        await Scripting.sleep(100);
    void instance._poll(oldState);
    oldState.networkAt = 0;
    void instance._pollNetwork(oldState);
    Main.extensionManager.disableExtension('system-resources@local');
    assert(!Main.panel.statusArea['system-resources@local'], 'Panel survives disable');
    assert(!oldTooltip._timer, 'Tooltip timer survives disable');
    Main.extensionManager.enableExtension('system-resources@local');
    await Scripting.sleep(3500);
    assert(!oldState.active && !oldState.process && !oldState.busy, 'Old collector remains active');
    assert(!oldState.network.process && !oldState.network.busy && !oldState.network.timeout,
        'Old network collection remains active');
    assert(!GLib.MainContext.default().find_source_by_id(oldState.timer), 'Old timer remains active');
    assert(extension.state === 1 && instance._values.RAM.text !== '—', 'Re-enable failed');
    const scale = Main.layoutManager.primaryMonitor.geometry_scale;
    console.log(`SYSTEM RESOURCES TEST PASSED (scale ${scale})`);
    global.context.terminate();
}
