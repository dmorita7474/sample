ユーザーとのやり取りは日本語とします。
アプリケーションの仕様に関する記載はdocs/ディレクトリ配下にmdで記載するようにしてください。

# アプリケーション概要

これは検証用プロジェクトです。AWS上にECSを構築し、サンプルアプリケーションをデプロイします。
ECS上でOpenTelemetryエージェントを通じてOTLPでCloudWatchAgentに送信し、CloudWatchAgentからCloudWatchおよびXrayにメトリクスデータが送られ、可視化できることのフィージビリティを確かめます。

このプロジェクトの仕様に関わるドキュメントはdocs/ディレクトリにまとめられています。

---

## プロジェクトセットアップ手順

このプロジェクトをAWS上にデプロイするための手順です。

### 1. 前提条件

- [AWS CLI](https://aws.amazon.com/cli/) がインストール���れ、デプロイ対象のAWSアカウントで認証情報が設定済みであること。
- [Terraform](https://www.terraform.io/downloads.html) (v1.0以降) がインストール済みであること。
- [Docker](https://www.docker.com/get-started) がインストール済みであること。

### 2. インフラストラクチャのデプロイ

Terraformを使用して、VPC、ECSクラスター、ECRリポジトリ、Auroraデータベースなどの基本的なインフラを構築します。

1.  **Terraformの初期化**

    ```bash
    cd terraform
    terraform init
    ```

2.  **デプロイの実行**

    ```bash
    terraform apply
    ```

    `apply`が完了すると、ECRリポジトリのURLやALBのDNS名などが出力されます。これらの値は次のステップで使用します。

### 3. アプリケーションのビルドとプッシュ

次に、フロントエンドとバックエンドのコンテナイメージをビルドし、作成されたECRリポジトリにプッシュします。

1.  **ECRへのDockerログイン**

    AWS CLIを使用して、ECRへの認証トークンを取得し���グインします。`<ACCOUNT_ID>` はご自身のAWSアカウントIDに置き換えてください。

    ```bash
    aws ecr get-login-password --region ap-northeast-1 | docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.ap-northeast-1.amazonaws.com
    ```

2.  **バックエンド (FastAPI) イメージのビルドとプッシュ**

    `<BACKEND_ECR_URL>` は `terraform apply` の出力から取得した `fastapi-app` のリポジトリURLに置き換えてください。

    ```bash
    cd ../backend
    docker build -t <BACKEND_ECR_URL>:latest .
    docker push <BACKEND_ECR_URL>:latest
    ```

3.  **フロントエンド (Next.js) イメージのビルドとプッシュ**

    `<FRONTEND_ECR_URL>` は `terraform apply` の出力から取得した `nextjs-app` のリポジトリURLに置き換えてください。

    ```bash
    cd ../frontend
    docker build -t <FRONTEND_ECR_URL>:latest .
    docker push <FRONTEND_ECR_URL>:latest
    ```

### 4. ECSサービスの更新

イメージがECRにプッシュされたら、ECSサービスを更新して新しいイメージを取得させ、タスクを再起動する必要があります。

1.  **サービスの更新**

    `<CLUSTER_NAME>` と `<SERVICE_NAME>` は `terraform apply` の出力やAWSコンソールで確認できます。（例: `ecs-opentelemetry-cluster`, `nextjs-service`, `fastapi-service`）

    ```bash
    # Next.jsサービスの更新
    aws ecs update-service --cluster <CLUSTER_NAME> --service nextjs-service --force-new-deployment --region ap-northeast-1

    # FastAPIサービスの更新
    aws ecs update-service --cluster <CLUSTER_NAME> --service fastapi-service --force-new-deployment --region ap-northeast-1
    ```

    デプロイが完了するまで数分かかります。

### 5. アプリケーションへのアクセス

デプロイが完了したら、`terraform apply` の出力に含まれる `alb_dns_name` のURLにブラウザでアクセスすると、ToDoアプリケーションが表示されます。

### 6. クリーンアップ

検証が完了したら、以下のコマンドで作成したすべてのAWSリソースを削除できま��。

```bash
cd ../terraform
terraform destroy
```