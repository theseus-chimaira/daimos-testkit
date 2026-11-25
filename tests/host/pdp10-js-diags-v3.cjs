"use strict";

// Boot acceptance test; optional diagnostic names require DIAMON.SAV.
// The public historical startup/login transcript lives in diags/README.md.
const fs = require("node:fs");
const path = require("node:path");
const assert = require("node:assert/strict");
const { setTimeout: sleep } = require("node:timers/promises");
const root = path.resolve(process.argv[2] || path.join(process.env.HOME, "git/pdp10-js"));
const mediaDir = process.argv[3];
assert.ok(mediaDir, "Specify the original TOPS-10 media directory");
const transcript = fs.readFileSync(path.join(root, "diags/README.md"), "utf8");
const login = transcript.match(/^Password: (\S+)\s*$/m);
assert.ok(login, "No documented historical guest login");
const { createMachine } = require(path.join(root, "node.js"));
let output = "";
let cursor = 0;
const names = process.argv.slice(4);
const machine = createMachine({
    mediaDir,
    output: text => { output += text; process.stdout.write(text); },
    reportError: message => { throw new Error(message); }
});

async function waitFor(pattern, timeout = 120000) {
    const deadline = Date.now() + timeout;
    for (;;) {
        const match = pattern.exec(output.slice(cursor));
        if (match) {
            const result = output.slice(cursor, cursor + match.index + match[0].length);
            cursor += result.length;
            return result;
        }
        assert.ok(Date.now() < deadline, "Timed out waiting for " + pattern);
        assert.equal(machine.context.CPU.halt, 0, "Unexpected CPU HALT");
        await sleep(100);
    }
}
async function command(pattern, input) {
    await waitFor(pattern);
    machine.input(input + "\r");
}
async function run() {
    machine.start();
    try {
        await command(/Boot> /, "boot dpa0");
        await command(/Press RETURN to continue loading BOOTS\.\.\.\r\n/, "");
        await command(/WHY RELOAD:/, "sched");
        await command(/DATE:/, "13-dec-78");
        await command(/TIME:/, "1121");
        await command(/STARTUP OPTION:/, "quick");
        await command(/CTY system 514[\r\n]+\./, "LOGIN 1,2");
        await command(/Password:/, login[1]);
        await command(/13-Dec-78[^\n]*Wed[\r\n]+\./i, "SYSTAT");
        await waitFor(/1 Jobs in use out of 64\.\s+1 logged in/);
        console.log("\nPASS: real TOPS-10 boot, login and SYSTAT");
        if (!names.length) return;
        await command(/[\r\n]\./, "RUN DIAMON");
        const monitor = await waitFor(/DIAMON CMD - |\?DIAMON\.SAV not found/i);
        assert.ok(/DIAMON CMD - $/.test(monitor), "DIAMON.SAV missing from guest search path");
        for (const name of names) {
            machine.input(name + "\r");
            const result = await waitFor(/DIAMON CMD - |\?Illegal instruction[^\r\n]*|\?[^\r\n]*(?:NOT FOUND|error)[^\r\n]*/i, 60000);
            if (!/DIAMON CMD - $/.test(result) || /\?|\bERROR\b/i.test(result)) {
                console.log("\nDIAG FAILURE " + name);
                process.exitCode = 1;
                return;
            }
            console.log("\nDIAG RETURNED " + name);
        }
    } finally {
        machine.close();
    }
}
run().catch(error => { console.error(error); process.exitCode = 1; });
