#!/bin/bash

# Kleuren voor output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log functies
log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuratie - PAS DEZE AAN NAAR JOUW REPOSITORY
DOTFILES_REPO="https://github.com/Breunder/Breundotfiles.git"
DOTFILES_DIR="$HOME/.dotfiles"
BACKUP_DIR="$HOME/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"

# Controleer of we op Arch Linux draaien
if ! command -v pacman &> /dev/null; then
    error "Dit script is ontworpen voor Arch Linux. Pacman niet gevonden."
    exit 1
fi

# Controleer of git is geïnstalleerd
if ! command -v git &> /dev/null; then
    log "Git is niet geïnstalleerd. Installeren..."
    sudo pacman -S --noconfirm git
fi

read -p "Wil je een backup maken van je bestaande dotfiles? (y/n): " make_backup
if [[ $make_backup =~ ^[Yy]$ ]]; then
    mkdir -p "$BACKUP_DIR"
    log "Backup directory aangemaakt: $BACKUP_DIR"
    
    # Backup maken van de hele .config directory
    if [ -d "$HOME/.config" ]; then
        cp -r "$HOME/.config" "$BACKUP_DIR/"
    fi
    if [ -f "$HOME/.zshrc" ]; then
        cp "$HOME/.zshrc" "$BACKUP_DIR/"
    fi
    
    success "Backup is gemaakt in: $BACKUP_DIR"
else
    log "Er zal geen backup worden gemaakt van bestaande dotfiles"
    # Clone of update repository
if [ -d "$DOTFILES_DIR" ]; then
    log "Dotfiles directory bestaat al, updating..."
    cd "$DOTFILES_DIR" || exit
    git pull
    success "Dotfiles repository bijgewerkt"
else
    log "Cloning dotfiles repository..."
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
    success "Dotfiles repository gecloned naar $DOTFILES_DIR"
fi

# Functie om symbolische links aan te maken
create_symlink() {
    local source_file="$1"
    local target_file="$2"
    
    # Maak doeldirectory indien nodig
    mkdir -p "$(dirname "$target_file")"
    
    # Controleer of het doelbestand al bestaat
    if [ -e "$target_file" ]; then
        # Als het al een symlink is naar ons bestand, sla over
        if [ -L "$target_file" ] && [ "$(readlink "$target_file")" = "$source_file" ]; then
            log "Link bestaat al: $target_file -> $source_file"
            return
        fi
        
        # Maak een backup van het bestaande bestand
        log "Backup maken van $target_file"
        mv "$target_file" "$BACKUP_DIR/$(basename "$target_file")"
    fi
    
    # Maak de symbolische link
    ln -sf "$source_file" "$target_file"
    success "Link aangemaakt: $target_file -> $source_file"
}

# Installeer Hyprland en afhankelijkheden
install_dependencies() {
    log "Installeren van Hyprland en afhankelijkheden..."
    
    # Zorg ervoor dat multilib repository is ingeschakeld
    if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
        log "Multilib repository inschakelen..."
        sudo sed -i "/\[multilib\]/,/Include/s/^#//g" /etc/pacman.conf
    fi
    
    # Update pacman database
    log "Pacman database updaten..."
    sudo pacman -Syu --noconfirm
    
    # Installeer yay als AUR helper indien niet aanwezig
    if ! command -v yay &> /dev/null; then
        log "Yay AUR helper installeren..."
        git clone https://aur.archlinux.org/yay.git /tmp/yay
        cd /tmp/yay || exit
        makepkg -si --noconfirm
        cd - || exit
        rm -rf /tmp/yay
    fi
    
    # Installeer Hyprland en essentiële pakketten
    # PAS DEZE LIJST AAN NAAR JOUW BEHOEFTEN
    log "Hyprland en essentiële pakketten installeren..."
    yay -S --needed --noconfirm hyprland waybar \
        xdg-desktop-portal-hyprland \
        kitty wofi \
        swww swaylock-effects-git swayidle \
        pipewire wireplumber pamixer \
        brightnessctl grim slurp wl-clipboard \
        polkit-kde-agent \
        ttf-jetbrains-mono-nerd ttf-font-awesome \
        network-manager-applet blueman \
        thunar \
        btop neofetch
    
    success "Hyprland en afhankelijkheden geïnstalleerd!"
}

# Installeer dotfiles
install_dotfiles() {
    log "Installeren van dotfiles..."
    
    # PAS DEZE LIJST AAN NAAR JOUW DOTFILES STRUCTUUR
    
    # Hyprland configuratie
    if [ -d "$DOTFILES_DIR/.config/hypr" ]; then
        create_symlink "$DOTFILES_DIR/.config/hypr" "$HOME/.config/hypr"
    fi
    
    # Waybar configuratie
    if [ -d "$DOTFILES_DIR/.config/waybar" ]; then
        create_symlink "$DOTFILES_DIR/.config/waybar" "$HOME/.config/waybar"
    fi
    
    # Rofi configuratie
    if [ -d "$DOTFILES_DIR/.config/rofi" ]; then
        create_symlink "$DOTFILES_DIR/.config/rofi" "$HOME/.config/rofi"
    fi
    
    # Kitty configuratie
    if [ -d "$DOTFILES_DIR/.config/kitty" ]; then
        create_symlink "$DOTFILES_DIR/.config/kitty" "$HOME/.config/kitty"
    fi
    
    # Hyprlock configuratie
    if [ -d "$DOTFILES_DIR/.config/swaylock" ]; then
        create_symlink "$DOTFILES_DIR/.config/hypr" "$HOME/.config/hypr"
    fi
    
    # Hypridle configuratie
    if [ -d "$DOTFILES_DIR/.config/hypr" ]; then
        create_symlink "$DOTFILES_DIR/.config/hypr" "$HOME/.config/hypr"
    fi
    
    # Swaync configuratie
    if [ -d "$DOTFILES_DIR/.config/swaync" ]; then
        create_symlink "$DOTFILES_DIR/.config/swaync" "$HOME/.config/swaync"
    fi
    
    # GTK thema configuratie
    if [ -d "$DOTFILES_DIR/.config/gtk-3.0" ]; then
        create_symlink "$DOTFILES_DIR/.config/gtk-3.0" "$HOME/.config/gtk-3.0"
    fi
    
    # Shell configuratie
    if [ -f "$DOTFILES_DIR/.zshrc" ]; then
        create_symlink "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
    fi
    if [ -f "$DOTFILES_DIR/.bashrc" ]; then
        create_symlink "$DOTFILES_DIR/.bashrc" "$HOME/.bashrc"
    fi
    
    # Neovim configuratie
    if [ -d "$DOTFILES_DIR/.config/nvim" ]; then
        create_symlink "$DOTFILES_DIR/.config/nvim" "$HOME/.config/nvim"
    fi
    
    # Wallpapers
    if [ -d "$DOTFILES_DIR/wallpapers" ]; then
        create_symlink "$DOTFILES_DIR/wallpapers" "$HOME/wallpapers"
    fi
    
    # Scripts
    if [ -d "$DOTFILES_DIR/.local/bin" ]; then
        create_symlink "$DOTFILES_DIR/.local/bin" "$HOME/.local/bin"
        # Zorg ervoor dat scripts uitvoerbaar zijn
        find "$HOME/.local/bin" -type f -exec chmod +x {} \;
    fi
    
    # VOEG HIER MEER CONFIGURATIEBESTANDEN TOE INDIEN NODIG
    
    success "Dotfiles geïnstalleerd!"
}

# Configureer autostart services
configure_services() {
    log "Configureren van systemd services..."
    
    # Bluetooth service
    sudo systemctl enable --now bluetooth.service
    
    # NetworkManager
    sudo systemctl enable --now NetworkManager.service
    
    # Pipewire
    systemctl --user enable --now pipewire.service
    systemctl --user enable --now pipewire-pulse.service
    systemctl --user enable --now wireplumber.service
    
    # VOEG HIER MEER SERVICES TOE INDIEN NODIG
    
    success "Services geconfigureerd!"
}

# Hoofdfunctie
main() {
    log "Start dotfiles installatie..."
    
    # Vraag of afhankelijkheden geïnstalleerd moeten worden
    read -p "Wil je Hyprland en afhankelijkheden installeren? (y/n): " install_deps
    if [[ $install_deps =~ ^[Yy]$ ]]; then
        install_dependencies
    fi
    
    # Installeer dotfiles
    install_dotfiles
    
    # Configureer services
    read -p "Wil je systemd services configureren? (y/n): " configure_svcs
    if [[ $configure_svcs =~ ^[Yy]$ ]]; then
        configure_services
    fi
    
    success "Dotfiles installatie voltooid!"
    log "Backup van originele bestanden: $BACKUP_DIR"
    log "Je kunt nu uitloggen en Hyprland selecteren bij het inloggen."
    log "Of start Hyprland direct met het commando 'Hyprland'"
}

# Start het script
main
