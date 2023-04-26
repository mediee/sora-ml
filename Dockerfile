# /Dockerfile
ARG PYTHON_BASE_IMAGE='python'

# Poetry をインストールするステージを示しています。
# Poetry は Python の依存関係管理とパッケージングを行うツールです。
FROM ${PYTHON_BASE_IMAGE}:3.11 AS poetry

# Python が pyc ファイルを作成するのを防ぎます。
# これは一時的なキャッシュファイルで、Docker イメージ内に不要なファイルを作成するのを避けるためです。
ENV PYTHONDONTWRITEBYTECODE=1

# 標準出力や標準エラーをバッファリングするのを防ぐことで、バッファリングによりログが出力されない状態でアプリケーションがクラッシュするのを避けます。
ENV PYTHONUNBUFFERED=1

RUN \
  --mount=type=cache,target=/var/lib/apt/lists \
  --mount=type=cache,target=/var/cache/apt/archives \
  apt-get update \
  && apt-get install -y --no-install-recommends build-essential

ENV POETRY_HOME="/opt/poetry"
ENV PATH="$POETRY_HOME/bin:$PATH"

RUN curl -sSL https://install.python-poetry.org | python3 - \
    && poetry config virtualenvs.create false \
    && mkdir -p /cache/poetry \
    && poetry config cache-dir /cache/poetry

# Docker のキャッシュを活用するため、依存関係のダウンロードを別のステップで行います。
# 次回のビルドを速くするために、/cache/poetry へのキャッシュマウントを利用します。
# このレイヤーに pyproject.toml や poetry.lock をコピーする必要がないように、バインドマウントを活用します。
RUN --mount=type=cache,target=/cache/poetry \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    --mount=type=bind,source=poetry.lock,target=poetry.lock \
    poetry install --no-interaction --no-root --without dev


# 開発環境用のステージを示しています。
FROM poetry AS dev
WORKDIR /workspace

# 秘密鍵をコピーしてremote containerの中からgitを使えるようにしています
RUN mkdir -p ~/.ssh && ln -s /run/secrets/host_ssh_key ~/.ssh/id_rsa
RUN echo 'eval `ssh-agent`' >> ~/.bashrc
RUN echo 'ssh-add ~/.ssh/id_rsa' >> ~/.bashrc

# src 以下にアプリケーションコードを記述しています。
# ビジネスロジックをテストやスクリプトから参照（import）するために PYTHONPATH 環境変数を指定します。
ENV PYTHONPATH="/workspace/src:$PYTHONPATH"

# オプション。
# DB として PostgreSQL を使っていたため、ここでは追加で postgresql-client をインストールしています。
RUN \
  --mount=type=cache,target=/var/lib/apt/lists \
  --mount=type=cache,target=/var/cache/apt/archives \
  apt-get update \
  && apt-get install -y --no-install-recommends postgresql-client


RUN --mount=type=cache,target=/cache/poetry \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    --mount=type=bind,source=poetry.lock,target=poetry.lock \
    poetry config virtualenvs.create false && \
    poetry install --no-interaction --no-root

# 本番環境用のステージです。
FROM poetry AS run

WORKDIR /app

# 特権のないユーザーを作成し、そのユーザーとしてアプリケーションを実行します。
# これは Docker のベストプラクティスで、アプリケーションがシステム全体に対する潜在的な攻撃から守るための重要なステップです。
# https://docs.docker.com/develop/develop-images/dockerfile_best-practices/#user
ARG UID=10001
RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "/nonexistent" \
    --shell "/sbin/nologin" \
    --no-create-home \
    --uid "${UID}" \
    appuser

# 特権のないユーザーへ切り替え、そのユーザーとしてアプリケーションを実行します。
USER appuser

COPY . .

ENTRYPOINT ["python3", "./main.py"]
