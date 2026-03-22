// Hook: UserPromptSubmit
// Saves the current prompt and project dir/HEAD to temp files.
let data = '';
process.stdin.on('data', chunk => data += chunk);
process.stdin.on('end', () => {
    try {
        const fs = require('fs');
        const { execSync } = require('child_process');
        const obj = JSON.parse(data);
        const prompt = (obj.prompt || '').trim().replace(/\r?\n/g, ' ');
        const projectDir = process.cwd().replace(/\//g, '\\');

        const tmp = 'C:\\Users\\' + require('os').userInfo().username + '\\AppData\\Local\\Temp\\';
        fs.writeFileSync(tmp + 'last_prompt.txt', prompt, 'utf8');
        fs.writeFileSync(tmp + 'last_dir.txt', projectDir, 'utf8');

        try {
            const head = execSync('git rev-parse HEAD', {
                cwd: projectDir,
                encoding: 'utf8',
                stdio: ['pipe', 'pipe', 'ignore']
            }).trim();
            fs.writeFileSync(tmp + 'last_head.txt', head, 'utf8');
        } catch(e) {}
    } catch(e) {}
});
