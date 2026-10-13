import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import {fileURLToPath} from "node:url";

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), "..");
const snapshotPath = path.join(root, ".github", "workflows", "repo-source-snapshot.yml");
const publisherPath = path.join(root, ".github", "workflows", "workflow-mailbox-publisher.yml");
const snapshot = fs.readFileSync(snapshotPath, "utf8");
const publisher = fs.readFileSync(publisherPath, "utf8");

function requireText(text, pattern, label) {
  assert.match(text, pattern, label);
}

requireText(publisher, /\.workflow-mailbox\/\$\{MAILBOX_KEY\}/, "publisher mailbox directory");
requireText(publisher, /runs_dir=.*\/runs/, "publisher immutable run directory");
requireText(publisher, /MAILBOX_BRANCH: workflow-mailbox/, "dedicated mailbox branch");
requireText(publisher, /git checkout --orphan/, "publisher creates the mailbox branch without source files");
requireText(publisher, /git ls-remote --exit-code --heads origin "refs\/heads\/\$\{MAILBOX_BRANCH\}"/, "publisher checks for the dedicated branch");
requireText(publisher, /git rm -rf --ignore-unmatch \./, "initial branch drops the source checkout tree");
requireText(publisher, /for latest_file in .*latest\.json/, "publisher per-workflow and root latest pointers");
requireText(publisher, /git add .*latest\.json/, "publisher stages the root latest pointer");
requireText(publisher, /candidate_id.*candidate_attempt/, "numeric run and attempt comparison");
requireText(publisher, /git fetch --no-tags origin/, "mailbox branch-head refresh before push");
requireText(publisher, /git push origin \"HEAD:refs\/heads\/\$\{MAILBOX_BRANCH\}\"/, "non-force push to mailbox branch");
assert.ok(publisher.includes('.workflow-mailbox/*|latest.json)'), "branch content allowlist");
assert.ok(publisher.includes('*) git rm -f -- "${tracked_file}" ;;'), "publisher prunes files outside the allowlist");
assert.doesNotMatch(publisher, /--force(?:-with-lease)?\b/, "publisher must never force-push");
requireText(snapshot, /workflow-mailbox-publisher\.yml/, "snapshot calls mailbox publisher");
requireText(snapshot, /if: always\(\)/, "mailbox runs after snapshot result");
requireText(snapshot, /needs: \[snapshot\]/, "mailbox depends on snapshot");
requireText(snapshot, /workflow_key: repo-source-snapshot/, "stable mailbox key");
requireText(snapshot, /source_sha: \$\{\{ needs\.snapshot\.outputs\.snapshot_sha != '' && needs\.snapshot\.outputs\.snapshot_sha \|\| github\.sha \}\}/, "snapshot output source SHA with fallback");
requireText(snapshot, /artifact_url: \$\{\{ steps\.upload\.outputs\['artifact-url'\] \}\}/, "upload artifact URL output");
requireText(snapshot, /--exclude='\.workflow-mailbox\/\*\*'/, "mailbox metadata excluded from source archive");
requireText(snapshot, /snapshot:\s*\n\s*permissions:\s*\n\s*contents: read/, "snapshot read-only permission");
requireText(snapshot, /mailbox:\s*\n\s*if: always\(\)[\s\S]*?permissions:\s*\n\s*actions: read\s*\n\s*contents: write/, "mailbox write permissions");

console.log("source snapshot mailbox contract passed");
