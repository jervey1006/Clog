// Hook: UserPromptSubmit
// Appends the current prompt and project dir/HEAD to a session-scoped temp file (array).
let data = '';
process.stdin.on('data', chunk => data += chunk);
process.stdin.on('end', () => {
    try {
        const fs = require('fs');
        const os = require('os');
        const path = require('path');
        const { execSync } = require('child_process');
        const obj = JSON.parse(data);
        const sessionId = obj.session_id || 'default';
        const prompt = (obj.prompt || '').trim().replace(/\r?\n/g, ' ');
        const projectDir = process.cwd().replace(/\//g, '\\');

        let head = null;
        try {
            head = execSync('git rev-parse HEAD', {
                cwd: projectDir,
                encoding: 'utf8',
                stdio: ['pipe', 'pipe', 'ignore']
            }).trim();
        } catch(e) {}

        const tmp = os.tmpdir();
        const file = path.join(tmp, `clog_${sessionId}.json`);

        // Read existing entries to avoid overwriting previous prompts in the same session
        let entries = [];
        try {
            const existing = fs.readFileSync(file, 'utf8');
            const parsed = JSON.parse(existing);
            entries = Array.isArray(parsed) ? parsed : [parsed];
        } catch(e) {}

        entries.push({ prompt, dir: projectDir, head });
        fs.writeFileSync(file, JSON.stringify(entries), 'utf8');
    } catch(e) {
        try {
            const fs = require('fs');
            const os = require('os');
            const path = require('path');
            const errFile = path.join(os.tmpdir(), 'clog_error.log');
            fs.appendFileSync(errFile, `[${new Date().toISOString()}] read_prompt error: ${e.message}\n`);
        } catch(e2) {}
    }
});
