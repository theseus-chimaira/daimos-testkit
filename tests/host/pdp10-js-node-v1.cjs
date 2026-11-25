"use strict";

// Run against the native PDP-10 JS host in the sibling repository.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { spawn } = require("node:child_process");
const { setTimeout: sleep } = require("node:timers/promises");
const root = path.resolve(process.argv[2] || path.join(process.env.HOME, "git/pdp10-js"));
const { createMachine } = require(path.join(root, "node.js"));
const tmp = process.env.TMPDIR || path.join(process.env.HOME, "tmp");
fs.mkdirSync(tmp, { recursive: true });
const dir = fs.mkdtempSync(path.join(tmp, "pdp10-js-node-v1-"));

async function until(predicate) {
    for (let i = 0; i < 500; i++) {
        if (predicate()) return;
        await sleep(10);
    }
    assert.fail("Timed out");
}

async function cliTest() {
    const child = spawn(process.execPath, [path.join(root, "node.js"), "--media-dir", dir]);
    let out = "", err = "";
    child.stdout.on("data", b => { out += b; });
    child.stderr.on("data", b => { err += b; });
    const exited = new Promise(resolve => child.once("exit", resolve));
    try {
        await until(() => out.includes("Boot> "));
        child.stdin.write("help\n");
        await until(() => out.includes("Commands are BOOT, HELP"));
        await until(() => out.split("Boot> ").length >= 4);
        child.stdin.write("boot dpa1\n");
        await until(() => err.includes("dpa1.dsk"));
        await until(() => out.split("Boot> ").length >= 5);
        child.stdin.write("boot dpa0\n");
        await until(() => err.includes("HALT @"));
        assert.match(out, /Press RETURN to continue loading BOOTS/);
        console.log("PASS: native CTY HELP, missing disk recovery, RP03 bootstrap to HALT");
    } finally {
        child.stdin.end();
        child.kill("SIGTERM");
        await exited;
    }
}

async function main() {
    // A synthetic SIMH RP03 image with a HALT at the boot sector.
    const image = Buffer.alloc(5 * 128 * 8);
    image.writeBigUInt64LE(0o254200777000n, 4 * 128 * 8);
    fs.writeFileSync(path.join(dir, "dpa0.dsk"), image);
    let printed = "", errors = 0;
    const machine = createMachine({ mediaDir: dir, printer: s => { printed += s; },
        reportError: () => { errors++; } });
    const ctx = machine.context;
    try {
        const read = (name, block) => new Promise(resolve => ctx.diskBlockReader(name, block, resolve));
        const result = await read("dpa0.dsk", 0);
        assert.equal(result.status, 206);
        assert.equal(result.response.length, image.length);
        assert.deepEqual(result.response, image);
        const cache = [];
        assert.equal(ctx.extractXHR(result, cache, 0), 0);
        assert.equal(cache[0].length, 1024 * 1024);
        assert.equal(cache[0][image.length], 0);
        assert.equal((await read("dpa0.dsk", 1)).status, 416);
        assert.equal((await read("missing.dsk", 0)).status, 500);
        assert.equal(errors, 1);
        ctx.CPU.memory[0o100] = 65 * 2 ** 29 + 66 * 2 ** 22;
        ctx.ioLPT(3, 0o100);
        assert.equal(printed, "AB");
        ctx.ioAPR(3, 0o100);
        assert.equal(ctx.panel.dataSwitches, ctx.CPU.memory[0o100]);
        console.log("PASS: bounded block reads, EOF, error, cache padding, printer, panel");
    } finally {
        machine.close();
    }
    await cliTest();
}

main().catch(error => { console.error(error); process.exitCode = 1; })
    .finally(() => fs.rmSync(dir, { recursive: true, force: true }));
