// Run only in the isolated session created by run-shell-test.py.
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Shell from 'gi://Shell';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as Scripting from 'resource:///org/gnome/shell/ui/scripting.js';

function assert(condition, message) {
    if (!condition)
        throw new Error(message);
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
    await Scripting.sleep(3500);
    assert([...instance._disks.values()].every(item => item.value.text !== '—'), 'Missing disk readings');
    assert(instance._apps.some(item => item.item.visible && item.title.text !== '…'),
        'Missing application readings');
    assert([...instance._volatileRows.values()].map(item => item.title.text).join(',') === 'Home,Root',
        'Volatile storage must contain only Home and Root');
    const capacityRows = [...instance._disks.values(), ...instance._volatileRows.values(),
        instance._ram, instance._vram];
    for (const item of capacityRows.filter(item => item.value.text.includes('/'))) {
        assert(item.value.text.indexOf('/') === 10, 'Capacity columns do not align');
        assert(item.bar.visible, 'Capacity row is missing its usage bar');
    }
    assert(instance._indicator.menu.actor.height < global.stage.height, 'Menu exceeds screen height');
    assert(global.stage.get_key_focus() === instance._scroll, 'Menu did not receive keyboard focus');
    const color = instance._disks.get('/p-os').bar.get_theme_node().get_color('-barlevel-active-background-color');
    assert(color.alpha > 0, 'Usage bars did not inherit the theme');
    await capture('menu');

    const adjustment = instance._scroll.vadjustment;
    adjustment.value = adjustment.upper - adjustment.page_size;
    await Scripting.sleep(500);
    await capture('menu-bottom');
    instance._sortButtons.vram.emit('clicked', 1);
    assert(instance._consumerMode === 'vram' && instance._sortButtons.vram.checked &&
        !instance._sortButtons.ram.checked, 'VRAM selection failed');
    assert(instance._apps.filter(item => item.item.visible).length === instance._applications.vramItems.length,
        'VRAM consumers did not replace RAM consumers');
    await Scripting.sleep(500);
    await capture('menu-vram');
    instance._sortButtons.ram.emit('clicked', 1);
    assert(instance._sortButtons.ram.checked && !instance._sortButtons.vram.checked,
        'RAM selection failed');
    instance._indicator.menu.close();

    instance._update({cpu: null, memory: null, gpu: null}, instance._state);
    assert(instance._values.RAM.text === '—' && instance._ram.value.text === 'Unavailable' &&
        instance._vram.value.text === 'Unavailable',
        'Missing readings were reported as zero usage');

    // Disable with a request in flight; old callbacks must not affect a new cycle.
    for (let retry = 0; instance._state.busy && retry < 20; retry++)
        await Scripting.sleep(100);
    const oldState = instance._state;
    void instance._poll(oldState);
    Main.extensionManager.disableExtension('system-resources@local');
    assert(!Main.panel.statusArea['system-resources@local'], 'Panel survives disable');
    Main.extensionManager.enableExtension('system-resources@local');
    await Scripting.sleep(3500);
    assert(!oldState.active && !oldState.process && !oldState.busy, 'Old collector remains active');
    assert(!GLib.MainContext.default().find_source_by_id(oldState.timer), 'Old timer remains active');
    assert(extension.state === 1 && instance._values.RAM.text !== '—', 'Re-enable failed');
    const scale = Main.layoutManager.primaryMonitor.geometry_scale;
    console.log(`SYSTEM RESOURCES TEST PASSED (scale ${scale})`);
    global.context.terminate();
}
