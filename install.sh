#!/bin/bash

# Kleuren voor output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
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

section() {
    echo -e "\n${MAGENTA}==>${NC} ${CYAN}$1${NC}"
    echo -e "${MAGENTA}$(printf '=%.0s' $(seq 1 $(( ${#1} + 4 ))))${NC}"
}

# Configuratie - PAS DEZE AAN NAAR JOUW REPOSITORY
DOTFILES_REPO="https://github.com/Breunder/Breundotfiles.git"
DOTFILES_DIR="$HOME/.dotfiles"
BACKUP_DIR="$HOME/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"

# DEEL 1: Systeemcontroles
check_system() {
    section "Systeemcontroles uitvoeren"
    
    # Controleer of we op Arch Linux draaien
    if ! command -v pacman &> /dev/null; then
        error "Dit script is ontworpen voor Arch Linux. Pacman niet gevonden."
        exit 1
    fi
    success "Arch Linux gedetecteerd."

    # Controleer of git is geïnstalleerd
    if ! command -v git &> /dev/null; then
        log "Git is niet geïnstalleerd. Installeren..."
        sudo pacman -S --noconfirm git
        success "Git geïnstalleerd."
    else
        success "Git is al geïnstalleerd."
    fi
    
    # Controleer internetverbinding
    if ping -c 1 archlinux.org &> /dev/null; then
        success "Internetverbinding is beschikbaar."
    else
        error "Geen internetverbinding. Controleer je netwerk en probeer opnieuw."
        exit 1
    fi
    
    # Controleer of script als root wordt uitgevoerd
    if [ "$EUID" -eq 0 ]; then
        error "Dit script moet niet als root worden uitgevoerd."
        exit 1
    fi
    
    # Controleer beschikbare schijfruimte
    AVAILABLE_SPACE=$(df -h / | awk 'NR==2 {print $4}')
    log "Beschikbare schijfruimte: $AVAILABLE_SPACE"
}

# DEEL 2: Backup maken
create_backup() {
    section "Backup van bestaande configuratie maken"
    
    read -p "Wil je een backup maken van je bestaande dotfiles? (y/n): " make_backup
    if [[ $make_backup =~ ^[Yy]$ ]]; then
        mkdir -p "$BACKUP_DIR"
        log "Backup directory aangemaakt: $BACKUP_DIR"
        
        # Backup maken van de hele .config directory
        if [ -d "$HOME/.config" ]; then
            log "Backup maken van .config directory..."
            cp -r "$HOME/.config" "$BACKUP_DIR/"
        fi
        
        # Backup maken van shell configuratie
        if [ -f "$HOME/.zshrc" ]; then
            log "Backup maken van .zshrc..."
            cp "$HOME/.zshrc" "$BACKUP_DIR/"
        fi
        if [ -f "$HOME/.bashrc" ]; then
            log "Backup maken van .bashrc..."
            cp "$HOME/.bashrc" "$BACKUP_DIR/"
        fi
        
        success "Backup is gemaakt in: $BACKUP_DIR"
    else
        log "Er zal geen backup worden gemaakt van bestaande dotfiles"
    fi
}

# DEEL 3: Repository instellen
setup_repository() {
    section "Dotfiles repository instellen"
    
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
    
    # Controleer of de repository succesvol is gecloned
    if [ ! -d "$DOTFILES_DIR" ]; then
        error "Dotfiles repository kon niet worden gecloned. Controleer de URL en je internetverbinding."
        exit 1
    fi
}

# DEEL 4: Symbolische links maken
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
        if [ -d "$target_file" ]; then
            cp -r "$target_file" "$BACKUP_DIR/$(basename "$target_file")"
        else
            cp "$target_file" "$BACKUP_DIR/$(basename "$target_file")"
        fi
        rm -rf "$target_file"
    fi
    
    # Maak de symbolische link
    ln -sf "$source_file" "$target_file"
    success "Link aangemaakt: $target_file -> $source_file"
}

# DEEL 5: Installeer Hyprland en afhankelijkheden
install_dependencies() {
    section "Hyprland en afhankelijkheden installeren"
    
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
        sudo pacman -S --needed --noconfirm base-devel
        git clone https://aur.archlinux.org/yay.git /tmp/yay
        cd /tmp/yay || exit
        makepkg -si --noconfirm
        cd - || exit
        rm -rf /tmp/yay
        success "Yay geïnstalleerd."
    else
        success "Yay is al geïnstalleerd."
    fi
    
    # Installeer Hyprland en essentiële pakketten
    log "Hyprland en essentiële pakketten installeren..."
    
    # Basis Hyprland pakketten
    yay -S --needed --noconfirm hyprland waybar \
        xdg-desktop-portal-hyprland \
        kitty rofi-wayland \
        swww swaylock-effects-git hypridle \
        pipewire wireplumber pamixer \
        brightnessctl grim slurp cliphist \
        polkit-kde-agent \
        ttf-jetbrains-mono-nerd ttf-font-awesome \
        nm-connection-editor blueman \
        thunar \
        btop neofetch
    
    success "Hyprland en afhankelijkheden geïnstalleerd!"
}

# DEEL 6: Installeer dotfiles
install_dotfiles() {
    section "Dotfiles installeren"
    
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
    
    # Swaylock configuratie
    if [ -d "$DOTFILES_DIR/.config/swaylock" ]; then
        create_symlink "$DOTFILES_DIR/.config/swaylock" "$HOME/.config/swaylock"
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
    
    success "Dotfiles geïnstalleerd!"
}

# DEEL 7: Configureer autostart services
configure_services() {
    section "Systemd services configureren"
    
    # Bluetooth service
    log "Bluetooth service configureren..."
    sudo systemctl enable --now bluetooth.service
    
    # NetworkManager
    log "NetworkManager service configureren..."
    sudo systemctl enable --now NetworkManager.service
    
    # Pipewire
    log "Pipewire services configureren..."
    systemctl --user enable --now pipewire.service
    systemctl --user enable --now pipewire-pulse.service
    systemctl --user enable --now wireplumber.service
    
    success "Services geconfigureerd!"
}

# DEEL 9: Configureer systeem
configure_system() {
    section "Systeem configureren"
    
    # Maak XDG gebruikersmappen aan
    if command -v xdg-user-dirs-update &> /dev/null; then
        log "XDG gebruikersmappen aanmaken..."
        xdg-user-dirs-update
        success "XDG gebruikersmappen aangemaakt."
    fi
    
    # Stel standaard shell in op zsh indien geïnstalleerd
    if command -v zsh &> /dev/null; then
        read -p "Wil je zsh als standaard shell instellen? (y/n): " set_zsh
        if [[ $set_zsh =~ ^[Yy]$ ]]; then
            log "Zsh als standaard shell instellen..."
            chsh -s $(which zsh)
            success "Zsh ingesteld als standaard shell."
        fi
    fi
    
    success "Systeem configuratie voltooid!"
}

# DEEL 10: Hoofdfunctie
main() {
    section "Dotfiles installatie starten"
    
    # Systeemcontroles
    check_system
    
    # Backup maken
    create_backup
    
    # Repository instellen
    setup_repository
    
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
    
    # Configureer systeem
    configure_system
    
    # Afronden
    section "Installatie voltooid"
    success "Dotfiles installatie voltooid!"
    log "Backup van originele bestanden: $BACKUP_DIR"
    log "Je kunt nu uitloggen en Hyprland selecteren bij het inloggen."
    log "Of start Hyprland direct met het commando 'Hyprland'"
    
    # Vraag om herstart
    read -p "Wil je het systeem nu herstarten? (y/n): " reboot_now
    if [[ $reboot_now =~ ^[Yy]$ ]]; then
        log "Systeem wordt herstart..."
        sudo reboot
    else
        log "Vergeet niet om later handmatig te herstarten voor de volledige werking."
    fi
}

# DEEL 11: Extra functies voor systeemonderhoud
system_maintenance() {
    section "Systeemonderhoud"
    
    read -p "Wil je systeemonderhoud uitvoeren? (y/n): " do_maintenance
    if [[ $do_maintenance =~ ^[Yy]$ ]]; then
        # Pacman cache opschonen
        log "Pacman cache opschonen..."
        sudo pacman -Sc --noconfirm
        
        # Verweesde pakketten verwijderen
        log "Verweesde pakketten zoeken en verwijderen..."
        orphans=$(pacman -Qtdq)
        if [ -n "$orphans" ]; then
            sudo pacman -Rns $orphans --noconfirm
            success "Verweesde pakketten verwijderd."
        else
            log "Geen verweesde pakketten gevonden."
        fi
        
        # Tijdelijke bestanden opschonen
        log "Tijdelijke bestanden opschonen..."
        rm -rf $HOME/.cache/yay/*
        
        success "Systeemonderhoud voltooid!"
    else
        log "Systeemonderhoud overgeslagen."
    fi
}

# DEEL 12: Help functie
show_help() {
    echo -e "${CYAN}Breundotfiles Installatiescript${NC}"
    echo -e "${CYAN}=============================${NC}"
    echo -e "Dit script installeert de Breundotfiles configuratie voor Hyprland op Arch Linux."
    echo -e ""
    echo -e "${YELLOW}Gebruik:${NC}"
    echo -e "  ./install.sh [optie]"
    echo -e ""
    echo -e "${YELLOW}Opties:${NC}"
    echo -e "  -h, --help      Toon deze help"
    echo -e "  --no-backup     Sla het maken van een backup over"
    echo -e "  --deps-only     Installeer alleen afhankelijkheden"
    echo -e "  --dotfiles-only Installeer alleen dotfiles"
    echo -e "  --maintenance   Voer alleen systeemonderhoud uit"
    echo -e ""
    echo -e "${YELLOW}Voorbeelden:${NC}"
    echo -e "  ./install.sh              # Voer het volledige installatiescript uit"
    echo -e "  ./install.sh --deps-only  # Installeer alleen afhankelijkheden"
    echo -e ""
}

# DEEL 13: Argumenten verwerken
process_args() {
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        --no-backup)
            log "Backup overslaan..."
            SKIP_BACKUP=true
            ;;
        --deps-only)
            log "Alleen afhankelijkheden installeren..."
            check_system
            install_dependencies
            exit 0
            ;;
        --dotfiles-only)
            log "Alleen dotfiles installeren..."
            check_system
            create_backup
            setup_repository
            install_dotfiles
            exit 0
            ;;
        --maintenance)
            log "Alleen systeemonderhoud uitvoeren..."
            check_system
            system_maintenance
            exit 0
            ;;
        "")
            # Geen argumenten, voer het volledige script uit
            ;;
        *)
            error "Onbekend argument: $1"
            show_help
            exit 1
            ;;
    esac
}

# Start het script
if [ $# -gt 0 ]; then
    process_args "$1"
else
    main
fi
