// SPDX-License-Identifier: AGPL-3.0-only

import { createPrivateKey } from 'node:crypto';
import { createAppAuth } from '@octokit/auth-app';

const TARGET_WORKFLOW = 'docker-build.yml';

function normalizePrivateKey(privateKey: string): string {
  if (privateKey.includes('-----BEGIN PRIVATE KEY-----')) {
    return privateKey;
  }

  return createPrivateKey(privateKey).export({
    type: 'pkcs8',
    format: 'pem',
  }).toString();
}

interface Env {
  GITHUB_OWNER: string;
  GITHUB_REPO: string;
  GITHUB_APP_ID: string;
  GITHUB_APP_PRIVATE_KEY: string;
  GITHUB_INSTALLATION_ID: string;
}

export default {
  async scheduled(_event: ScheduledEvent, env: Env, _ctx: ExecutionContext) {
    const auth = createAppAuth({
      appId: env.GITHUB_APP_ID,
      privateKey: normalizePrivateKey(env.GITHUB_APP_PRIVATE_KEY),
      installationId: env.GITHUB_INSTALLATION_ID,
    });

    const { token } = await auth({ type: 'installation' });

    const url = `https://api.github.com/repos/${env.GITHUB_OWNER}/${env.GITHUB_REPO}/actions/workflows/${TARGET_WORKFLOW}/dispatches`;

    const res = await fetch(url, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ ref: 'main' }),
    });

    if (!res.ok) {
      const body = await res.text();
      throw new Error(`dispatch failed: ${res.status} ${body}`);
    }
  },
};
