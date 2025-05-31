#!/bin/bash

asdf_dir="$HOME/.asdf"
asdf_nodejs_dir="$HOME/.asdf/plugins/nodejs"
asdf_java_dir="$HOME/.asdf/plugins/java"

# --------------- CORES PARA OUTPUT ---------------
red='\033[0;31m'
green='\033[0;32m'
nc='\033[0m' # no color
# ---------------

# --------------- FUNÇÃO PARA IMPRIMIR MENSAGENS DE STATUS ---------------
print_status() {
    echo -e "${green}[*] $1${nc}"
}
# ---------------

# --------------- FUNÇÃO PARA VERIFICAR SE O COMANDO FOI EXECUTADO COM SUCESSO ---------------
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${green}[✓] $1${nc}"
    else
        echo -e "${red}[✗] erro ao $1${nc}"
        exit 1
    fi
}
# ---------------

# --------------- ATUALIZAR O SISTEMA ---------------
print_status "atualizando o sistema..."
sudo apt update && sudo apt upgrade -y
check_status "atualizar o sistema"
# ---------------

# --------------- INSTALAR PACOTES ESSENCIAIS ---------------
print_status "instalando pacotes essenciais..."
sudo apt install -y \
    curl \
    wget \
    git \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release
check_status "instalar pacotes essenciais"
# ---------------

# --------------- INSTALAR FERRAMENTAS DE DESENVOLVIMENTO C ---------------
print_status "instalando ferramentas de desenvolvimento c..."
sudo apt install -y \
    build-essential \
    gcc \
    g++ \
    make \
    cmake \
    libc6-dev
check_status "instalar ferramentas de desenvolvimento"
# ---------------

# --------------- INSTALAR APPS DE TERMINAL ---------------
print_status "instalando apps de terminal..."
sudo apt install -y \
    micro \
    neovim \
    ranger \
    bat \
    btop \
    tmux \
    python3-dev \
    python3-pip
check_status "instalar apps de terminal"
# ---------------

# --------------- INSTALAR APPS DE SISTEMA ---------------
print_status "instalando apps de sistema..."
sudo apt install -y \
    qlipper \
    flameshot \
    filezilla \
    vlc \
    timeshift \
    chromium \
    meld
check_status "instalar apps de sistema"
# ---------------

# --------------- INSTALAR DOCKER ---------------
print_status "instalando docker..."
# Remover versões antigas do Docker
sudo apt remove -y docker docker-engine docker.io containerd runc

# Adicionar chave GPG oficial do Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

UBUNTU_CODENAME="noble"

# Adicionar repositório do Docker
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $UBUNTU_CODENAME stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Atualizar lista de pacotes e instalar Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Iniciar e habilitar Docker
sudo systemctl start docker
sudo systemctl enable docker
check_status "instalar docker"
# ---------------

# --------------- ADICIONAR USUÁRIO AO GRUPO DOCKER ---------------
print_status "adicionando usuário ao grupo docker..."
sudo usermod -aG docker $USER
check_status "adicionar usuário ao grupo docker"
# ---------------

# --------------- INSTALAR VISUAL STUDIO CODE ---------------
print_status "instalando visual studio code..."
# Adicionar chave GPG da Microsoft
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'

# Atualizar lista de pacotes e instalar VS Code
sudo apt update
sudo apt install -y code
check_status "instalar vscode"
# ---------------

# --------------- INSTALAR DISTROBOX ---------------
print_status "instalando distrobox..."
# Instalar via script oficial
curl -s https://raw.githubusercontent.com/89luca89/distrobox/main/install | sudo sh
check_status "instalar distrobox"
# ---------------

# --------------- INSTALAR OH-MY-ZSH! ---------------
# print_status "instalando Oh-my-zsh!..."
# sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
# check_status "instalar Oh-my-zsh!"
# ---------------

# --------------- INSTALAR ASDF MANAGER ---------------
if [[ ! -d $asdf_dir ]]; then 
    print_status "instalando asdf manager..."
    git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.15.0
    check_status "instalar asdf manager"

    # adicionando comandos ao .bashrc
    cat >> ~/.bashrc << EOF

# asdf
. "$HOME/.asdf/asdf.sh"
. "$HOME/.asdf/completions/asdf.bash"
EOF

    source ~/.bashrc
fi

if [[ ! -d $asdf_nodejs_dir ]]; then 
    print_status "instalando plugin de nodejs do asdf..."
    ~/.asdf/bin/asdf plugin-add nodejs
    check_status "instalar plugin de nodejs do asdf"
fi

if [[ ! -d $asdf_java_dir ]]; then 
    print_status "instalando plugin de java do asdf..."
    ~/.asdf/bin/asdf plugin-add java
    check_status "instalar plugin de java do asdf"
fi
# ---------------

# --------------- CONFIGURAR FLATPAK ---------------
print_status "configurando flatpak..."
# Flatpak já vem instalado no Linux Mint
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
check_status "configurar flatpak"
# ---------------

# --------------- INSTALAR APPS FLATPAK ---------------
print_status "instalando apps flatpak..."
flatpak install -y flathub \
    com.github.tchx84.Flatseal \
    com.obsproject.Studio \
    eu.scarpetta.PDFMixTool \
    md.obsidian.Obsidian \
    org.telegram.desktop \
    com.rustdesk.RustDesk \
    com.bitwarden.desktop
check_status "instalar apps flatpak"
# ---------------

# --------------- CRIAR DIRETÓRIOS ---------------
print_status "criando diretórios..."
mkdir -p ~/workspace ~/gitclones
check_status "criar diretórios"
# ---------------

# --------------- EXPORTAR VARIÁVEIS E FUNÇÕES PARA CONFIGURAÇÕES ADICIONAIS ---------------
export red green nc
export -f \
        print_status \
        check_status
# ---------------

# --------------- CONFIGURAÇÃO DE AMBIENTE PESSOAL ---------------
read -p "Gostaria de executar as configurações do ambiente pessoal?(s/N) " answer

if [[ "$answer" == [yYsS] ]]; then
    additional-setup/setup-personal.sh
fi
# ---------------

# --------------- CONFIGURAÇÃO DE AMBIENTE DE TRABALHO ---------------
read -p "Gostaria de executar as configurações do ambiente de trabalho?(s/N) " answer

if [[ "$answer" == [yYsS] ]]; then
    additional-setup/setup-work.sh
fi
# ---------------

print_status "Instalação concluída! Por favor, reinicie o sistema para aplicar todas as alterações."
