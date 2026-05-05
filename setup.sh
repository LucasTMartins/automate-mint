#!/bin/bash

# ================================================================
#  LINUX MINT POST-INSTALL SETUP
#  Inspirado no fluxo de containerização do Bluefin
#  Adaptado do script original para Fedora
# ================================================================

set -euo pipefail

# ----------------------------------------------------------------
#  CORES E HELPERS
# ----------------------------------------------------------------
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[1;33m'
blue='\033[0;34m'
cyan='\033[0;36m'
bold='\033[1m'
nc='\033[0m'

print_header() {
  echo ""
  echo -e "${bold}${cyan}════════════════════════════════════════${nc}"
  echo -e "${bold}${cyan}  $1${nc}"
  echo -e "${bold}${cyan}════════════════════════════════════════${nc}"
}

print_status() { echo -e "${green}[*] $1${nc}"; }
print_info() { echo -e "${blue}[i] $1${nc}"; }
print_warn() { echo -e "${yellow}[!] $1${nc}"; }
print_ok() { echo -e "${green}[✓] $1${nc}"; }
print_err() { echo -e "${red}[✗] $1${nc}"; }

check_status() {
  if [ $? -eq 0 ]; then
    print_ok "$1"
  else
    print_err "erro ao $1"
    exit 1
  fi
}

# Pergunta sim/não — retorna 0 (sim) ou 1 (não)
ask() {
  local prompt="$1"
  local default="${2:-N}"
  local answer
  echo -en "${yellow}[?] ${prompt} (s/N): ${nc}"
  read -r answer
  [[ "$answer" =~ ^[yYsS]$ ]]
}

# Verifica se um comando já existe no PATH
has_cmd() { command -v "$1" &>/dev/null; }

# ================================================================
#  1. BASE DO SISTEMA
# ================================================================
setup_system_base() {
  print_header "BASE DO SISTEMA"

  print_status "Atualizando a lista de pacotes..."
  sudo apt update -y
  check_status "atualizar lista de pacotes"

  print_status "Atualizando o sistema..."
  sudo apt upgrade -y
  check_status "atualizar o sistema"

  print_status "Instalando build-essential (ferramentas de desenvolvimento C/C++)..."
  sudo apt install -y build-essential
  check_status "instalar build-essential"

  print_status "Instalando dependências essenciais de build..."
  sudo apt install -y \
    curl wget git git-lfs \
    libssl-dev \
    libreadline-dev \
    libz-dev \
    libbz2-dev \
    libffi-dev \
    libsqlite3-dev \
    liblzma-dev \
    python3-dev \
    python3-pip \
    jq
  check_status "instalar dependências de build"

  # Atualizar para garantir que tudo está ok
  sudo apt autoremove -y
}

# ================================================================
#  2. FERRAMENTAS DE TERMINAL
# ================================================================
setup_terminal_tools() {
  print_header "FERRAMENTAS DE TERMINAL"

  print_status "Instalando utilitários de terminal..."
  sudo apt install -y \
    micro \
    neovim \
    ranger \
    bat \
    btop \
    tmux \
    fzf \
    ripgrep \
    lsd \
    zoxide \
    starship \
    ncdu \
    unzip zip p7zip-full
  check_status "instalar ferramentas de terminal"

  # lsd é um substituto para eza, que não está nos repositórios padrão do Mint
  print_info "Usando 'lsd' como alternativa ao 'eza'. Se preferir eza, instale manualmente via cargo."
}

# ================================================================
#  3. CONTAINERIZAÇÃO (estilo Bluefin)
# ================================================================
setup_containerization() {
  print_header "CONTAINERIZAÇÃO"

  # Podman — container engine rootless, base de tudo
  print_status "Instalando Podman..."
  sudo apt install -y podman podman-compose
  check_status "instalar Podman"

  # Distrobox — rodar outras distros sem sudo
  if ask "Deseja instalar Distrobox?"; then
    print_status "Instalando Distrobox..."
    sudo apt install -y distrobox
    check_status "instalar Distrobox"
    print_info "Use 'distrobox create --name <nome> --image <imagem>' para criar ambientes isolados."
  fi

  # Homebrew (Linuxbrew) — instalar apps de userspace sem sudo
  if ask "Deseja instalar o Homebrew?"; then
    print_status "Instalando Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c \
      "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    check_status "instalar Homebrew"

    # Adicionar brew ao shell
    local brew_profile='
# Homebrew
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'
    echo "$brew_profile" >>~/.bashrc
    [[ -f ~/.zshrc ]] && echo "$brew_profile" >>~/.zshrc
    print_info "Homebrew instalado. Reinicie o shell ou execute: eval \"\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\""
  fi

  # Docker — opcional, pois Podman já cobre a maioria dos casos
  if ask "Deseja instalar o Docker?"; then
    print_status "Instalando Docker (via script oficial)..."
    # Remove versões antigas, se houver
    for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
      sudo apt remove -y $pkg 2>/dev/null || true
    done
    # Instala via script oficial da Docker
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sudo sh /tmp/get-docker.sh
    check_status "instalar Docker"
    sudo systemctl enable --now docker
    sudo usermod -aG docker "$USER"
    print_warn "Você foi adicionado ao grupo 'docker'. Faça logout/login para que a mudança tenha efeito."
  fi
}

# ================================================================
#  4. GERENCIAMENTO DE VERSÕES — MISE
# ================================================================
setup_mise() {
  print_header "GERENCIAMENTO DE VERSÕES (MISE)"

  if has_cmd mise; then
    print_info "Mise já está instalado. Pulando..."
    return
  fi

  print_status "Instalando Mise..."
  curl https://mise.run | sh
  check_status "instalar Mise"

  # Adicionar ao shell
  local mise_profile='
# Mise - gerenciador de versões
eval "$(~/.local/bin/mise activate bash)"'
  echo "$mise_profile" >>~/.bashrc

  if [[ -f ~/.zshrc ]]; then
    echo '
# Mise
eval "$(~/.local/bin/mise activate zsh)"' >>~/.zshrc
  fi

  # Ativar para a sessão atual
  eval "$(~/.local/bin/mise activate bash)" 2>/dev/null || true

  print_info "Mise instalado. Use 'mise use node@lts', 'mise use java@latest', etc."
}

# ================================================================
#  5. FLATPAK — CONFIGURAÇÃO E APPS
# ================================================================
setup_flatpak() {
  print_header "FLATPAK"

  print_status "Instalando/configurando Flatpak..."
  sudo apt install -y flatpak
  check_status "instalar Flatpak"

  print_status "Adicionando repositório Flathub..."
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  check_status "adicionar Flathub"
}

install_flatpak_browsers() {
  print_header "NAVEGADORES (Flatpak)"

  print_info "Navegadores rodam muito bem como Flatpak — sandbox nativa de segurança."

  #flatpak install -y flathub org.mozilla.firefox
  flatpak install -y flathub org.chromium.Chromium
  flatpak install -y flathub com.brave.Browser
}

install_flatpak_communication() {
  print_header "COMUNICAÇÃO (Flatpak)"

  if ask "Deseja instalar apps de comunicação (telegram, discord)?"; then
    flatpak install -y flathub org.telegram.desktop
    flatpak install -y flathub com.discordapp.Discord
  fi
}

install_flatpak_productivity() {
  print_header "PRODUTIVIDADE (Flatpak)"

  flatpak install -y flathub md.obsidian.Obsidian
  flatpak install -y flathub org.libreoffice.LibreOffice
}

install_flatpak_media() {
  print_header "MÍDIA E ENTRETENIMENTO (Flatpak)"

  flatpak install -y flathub org.videolan.VLC
  flatpak install -y flathub com.obsproject.Studio
}

install_flatpak_tools() {
  print_header "UTILITÁRIOS (Flatpak)"

  print_status "Instalando utilitários essenciais via Flatpak..."
  flatpak install -y flathub \
    com.github.tchx84.Flatseal \
    eu.scarpetta.PDFMixTool \
    org.gnome.FontManager
  flatpak install -y flathub com.rustdesk.RustDesk
  flatpak install -y flathub io.dbeaver.DBeaverCommunity
  flatpak install -y flathub org.qbittorrent.qBittorrent
  flatpak install -y flathub com.valvesoftware.Steam
  flatpak install -y flathub com.usebruno.Bruno
  flatpak install -y flathub io.github.kolunmi.Bazaar
  flatpak install -y flathub com.ranfdev.DistroShelf
  flatpak install -y flathub sh.loft.devpod
  check_status "instalar utilitários Flatpak essenciais"
}

# ================================================================
#  6. PACOTES NATIVOS — APPS QUE PRECISAM DE INTEGRAÇÃO PROFUNDA
# ================================================================
setup_native_apps() {
  print_header "APLICAÇÕES NATIVAS"

  print_info "Estas apps são instaladas nativamente por precisarem de integração com o sistema."

  # Ferramentas GUI de sistema
  print_status "Instalando utilitários de sistema..."
  sudo apt install -y \
    flameshot \
    qlipper \
    timeshift
  # ptyxis é específico do GNOME; no Mint (Cinnamon) não está disponível.
  # Vamos instalar gnome-terminal como alternativa, caso o usuário queira um terminal extra
  print_info "ptyxis não está disponível nos repositórios do Mint. Instalando gnome-terminal como alternativa..."
  sudo apt install -y gnome-terminal || print_warn "Não foi possível instalar gnome-terminal."
  check_status "instalar utilitários de sistema"

  # VSCode — nativo por causa de integração com Podman/Docker, SSH, extensões
  if ask "Deseja instalar o Visual Studio Code?"; then
    print_status "Instalando VSCode (via repositório Microsoft)..."
    # Importar chave GPG
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /usr/share/keyrings/packages.microsoft.gpg >/dev/null
    # Adicionar repositório
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list
    sudo apt update
    sudo apt install -y code
    check_status "instalar VSCode"
  fi

  # Timeshift já foi instalado acima
}

# ================================================================
#  7. ESTRUTURA DE DIRETÓRIOS
# ================================================================
setup_directories() {
  print_header "ESTRUTURA DE DIRETÓRIOS"

  print_status "Criando diretórios de trabalho..."
  mkdir -p \
    ~/workspace \
    ~/gitclones \
    ~/bin \
    ~/.local/bin
  check_status "criar diretórios"

  # Garantir que ~/bin está no PATH
  if ! grep -q 'export PATH="$HOME/bin' ~/.bashrc; then
    echo 'export PATH="$HOME/bin:$HOME/.local/bin:$PATH"' >>~/.bashrc
  fi
}

# ================================================================
#  MAIN
# ================================================================
main() {
  print_header "LINUX MINT POST-INSTALL SETUP"
  echo -e "${blue}Este script irá configurar seu ambiente Linux Mint (base Ubuntu).${nc}"
  echo -e "${blue}Você será consultado antes de cada instalação opcional.${nc}"
  echo ""

  setup_system_base
  setup_terminal_tools
  setup_containerization
  setup_mise
  setup_flatpak
  install_flatpak_browsers
  install_flatpak_communication
  install_flatpak_productivity
  install_flatpak_media
  install_flatpak_tools
  setup_native_apps
  setup_directories

  print_header "INSTALAÇÃO CONCLUÍDA"
  echo -e "${green}Tudo pronto! Algumas mudanças requerem reinicialização para ter efeito.${nc}"
  echo ""
  echo -e "${yellow}Próximos passos sugeridos:${nc}"
  echo -e "  • Reinicie o sistema"
  echo -e "  • Configure o Starship: https://starship.rs/config/"
  echo -e "  • Crie seu primeiro distrobox: distrobox create --name dev --image ubuntu:24.04"
  echo -e "  • Configure o Mise: mise use --global node@lts python@latest"
  echo ""

  if ask "Deseja reiniciar o sistema agora?"; then
    sudo reboot
  fi
}

main "$@"
