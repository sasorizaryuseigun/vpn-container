<!-- SPDX-License-Identifier: AGPL-3.0-only -->

# VPN Container

SoftEther VPN Serverをコンテナ化して配布するためのリポジトリです。

`Dockerfile`でSoftEther VPN Serverをビルドし、
最終的に`scratch`ベースの最小イメージを生成します。
あわせて`worker/`には、GitHub ActionsのDockerビルド用workflowを
定期実行するCloudflare Workerが含まれています。

## 構成

- `Dockerfile`: SoftEther VPN Serverのビルドとランタイムイメージの生成
- `worker/`: GitHub Actions workflowを定期実行するCloudflare Worker

## コンテナイメージの特徴

- SoftEther VPN Serverをソースからビルド
- `scratch`ベースの最終イメージを生成
- 実行に必要なバイナリと依存ライブラリだけを同梱
- `vpnserver`と`vpncmd`を`rust-exec`経由で起動
- 初期の管理アクセス制限用`adminip.txt`を同梱

## Dockerfileの概要

ビルドは大きく2段階に分かれています。

1. DebianベースのbuilderステージでSoftEther VPN Serverをビルドします。
2. 必要な成果物だけを抽出し、`scratch`イメージへコピーします。

builderステージでは次の処理を行います。

- SoftEther VPN Server本体をclone
- submoduleを初期化
- patchを適用
- `./configure`と`make`でビルド
- `make install`で成果物を配置
- `rust-exec`をビルドして`vpnserver`と`vpncmd`のラッパーとして差し替え
- `miroot`で実行時に必要なファイルのみを`/out`へ収集

### 適用しているpatchの概要

ビルド時に適用している外部patchでは、主に次の変更を加えています。

- SoftEther VPNのenterprise functionsに対するオープンソース版の地域制限チェックを無効化
- 配布物のライセンス表記を変更内容に合わせて調整
- `eula.txt`へ改変内容とライセンスに関する説明を追記

最終イメージでは以下のポートを公開しています。

- `443`
- `992`
- `5555`
- `8888`

デフォルトの起動コマンドは次のとおりです。

```sh
/usr/local/bin/vpnserver execsvc
```

## イメージのビルド

リポジトリルートで次を実行します。

```sh
docker build -t vpn .
```

## コンテナの起動例

最小構成の例です。

```sh
docker run --rm -p 443:443 -p 992:992 -p 5555:5555 -p 8888:8888 vpn
```

永続化が必要な場合は、SoftEtherのデータディレクトリやログディレクトリを適切にマウントして運用してください。

対象ディレクトリはDockerfile上では次の場所です。

- `/var/log/softether`
- `/var/lib/softether`

## Cloudflare Worker

`worker/`には、GitHub App認証を使ってGitHub Actions workflowを定期実行するCloudflare Workerが含まれています。

このWorkerは、cron triggerで毎月1日の`00:00 JST`に起動し、対象リポジトリの`docker-build.yml`workflowへ`workflow_dispatch`を送信します。

### 役割

- GitHub Appの秘密鍵を正規化
- installation tokenを取得
- GitHub Actionsのworkflow dispatch APIを呼び出し

### 必要な環境変数

`worker/src/index.ts`では次の環境変数を使用します。

- `GITHUB_OWNER`
- `GITHUB_REPO`
- `GITHUB_APP_ID`
- `GITHUB_APP_PRIVATE_KEY`
- `GITHUB_INSTALLATION_ID`

### ローカル開発

`worker/`ディレクトリで次を実行します。

```sh
pnpm dev
```

### デプロイ

`worker/`ディレクトリで次を実行します。

```sh
pnpm deploy
```
