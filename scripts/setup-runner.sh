#!/bin/bash
# ==============================================================================
# Setup do GitHub Actions self-hosted runner local
#
# O cluster kind vive em localhost, então a pipeline do app (build + deploy
# via ArgoCD/GitOps) precisa rodar numa máquina que "enxerga" o Docker e o
# cluster. Este script baixa, instala e registra um runner self-hosted.
#
# Pré-requisito: um token de registro do GitHub (clássico ou fine-grained).
#   Obtenha em: Settings > Actions > Runners > New self-hosted runner
#   OU via API: gh api repos/<owner>/<repo>/actions/runners/registration-token
# ==============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
step(){ echo -e "\n${GREEN}==> $1${NC}"; }
err(){ echo -e "${RED}ERROR: $1${NC}"; exit 1; }

RUNNER_VERSION="${RUNNER_VERSION:-2.323.0}"
RUNNER_DIR="${RUNNER_DIR:-$HOME/actions-runner}"
REPO_URL="${REPO_URL:?Defina REPO_URL (ex: https://github.com/nikolastsdev/argo-test-manifests)}"
RUNNER_NAME="${RUNNER_NAME:-local-kind-runner}"
LABELS="${LABELS:-self-hosted,linux,x64,kind}"
RUNNER_TOKEN="${RUNNER_TOKEN:?Defina RUNNER_TOKEN (registration token)}"

# ------------------------------------------------------------------------------
# 1. Instalar Java (recomendado para o runner; versão LTS)
# ------------------------------------------------------------------------------
step "Garantindo Java 17 (runner requer JVM)"
if ! command -v java >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then
    warn() { echo -e "${YELLOW}WARN: $1${NC}"; }
    sudo apt-get update
    sudo apt-get install -y openjdk-17-jre-headless
  else
    err "Java não está instalado. Instale o OpenJDK 17 e rode novamente."
  fi
fi
echo "Java: $(java -version 2>&1 | head -1)"

# ------------------------------------------------------------------------------
# 2. Baixar e extrair o runner (se ainda não existir)
# ------------------------------------------------------------------------------
step "Preparando runner na pasta $RUNNER_DIR"
if [ ! -d "$RUNNER_DIR" ]; then
  mkdir -p "$RUNNER_DIR"
  ARCH="$(dpkg --print-architecture 2>/dev/null || echo x64)"
  PKG="actions-runner-linux-${ARCH}-${RUNNER_VERSION}.tar.gz"
  curl -sSL -o /tmp/runner.tgz \
    "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${PKG}"
  tar xzf /tmp/runner.tgz -C "$RUNNER_DIR"
  rmdir "$RUNNER_DIR/.credentials" 2>/dev/null || true
  rm -f /tmp/runner.tgz
fi

# ------------------------------------------------------------------------------
# 3. Registrar o runner (se não estiver registrado)
# ------------------------------------------------------------------------------
step "Registrando runner"
if [ -f "$RUNNER_DIR/.credentials" ]; then
  warn "Runner já registrado ($RUNNER_DIR/.credentials). Pulando registro.\n"
  warn "Para re-registrar: remova $RUNNER_DIR/.credentials e rode novamente."
else
  ( cd "$RUNNER_DIR" && ./config.sh \
      --url "$REPO_URL" \
      --token "$RUNNER_TOKEN" \
      --name "$RUNNER_NAME" \
      --labels "$LABELS" \
      --unattended \
      --replace )
fi

# ------------------------------------------------------------------------------
# 4. Iniciar o runner em background (modo serviço)
# ------------------------------------------------------------------------------
step "Instalando/Iniciando o runner como serviço (svc.sh)"
if command -v systemctl >/dev/null 2>&1 && [ -d "/etc/systemd/system" ]; then
  ( cd "$RUNNER_DIR"
    sudo ./svc.sh install && sudo ./svc.sh start ) || {
    warn "Falha ao instalar como serviço systemd."
    warn "Iniciando em foreground (use: $RUNNER_DIR/run.sh)"
  }
else
  warn "systemd não detectado. Inicie manualmente com: $RUNNER_DIR/run.sh"
fi

# ------------------------------------------------------------------------------
# 5. Status
# ------------------------------------------------------------------------------
step "Runner pronto!"
echo ""
echo "Runner dir : $RUNNER_DIR"
echo "Repository : $REPO_URL"
echo "Name/Labels: $RUNNER_NAME / $LABELS"
echo ""
echo "Dica: no workflow, use 'runs-on: self-hosted' para rodar no runner local."
echo ""