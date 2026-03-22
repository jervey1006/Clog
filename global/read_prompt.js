// Hook: UserPromptSubmit
// Saves the current prompt and project dir/HEAD to a session-scoped temp file.
let data = '';
process.stdin.on('data', chunk => data += chunk);
process.stdin.on('end', () => {
    try {
        const fs = require('fs');
        const os = require('os');
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
        const file = require('path').join(tmp, `clog_${sessionId}.json`);
        fs.writeFileSync(file, JSON.stringify({ prompt, dir: projectDir, head }), 'utf8');
    } catch(e) {}
});
