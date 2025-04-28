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

if [ ! -t 0 ]; then
    error "Dit script moet in een interactieve terminal worden uitgevoerd."
    exit 1
fi

get_yes_no() {
    while true; do
        echo -n "$1 (y/n): "
        stty raw
        answer=$(dd bs=1 count=1 2>/dev/null)
        stty -raw
        echo
        case $answer in
            [Yy]) return 0 ;;
            [Nn]) return 1 ;;
            *) echo "Antwoord met y of n." ;;
        esac
    done
}

# Configuratie
DOTFILES_REPO="https://github.com/Breunder/Breundotfiles.git"

# Add this function to select the branch
select_branch() {
    section "Branch selecteren"
    
    echo -e "${CYAN}Beschikbare branches:${NC}"
    echo "1) main - Stabiele versie (aanbevolen)"
    echo "2) testing - Nieuwste features (mogelijk onstabiel)"
    
    read -p "Kies een branch (1-2, standaard: 1): " branch_choice
    
    case $branch_choice in
        2)
            DOTFILES_BRANCH="Testing"
            log "Testing branch geselecteerd."
            ;;
        *)
            DOTFILES_BRANCH="main"
            log "Main branch geselecteerd."
            ;;
    esac
}

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
    elif ping -c 1 google.com &> /dev/null; then
        success "Internetverbinding is beschikbaar."
    elif curl -s --head http://www.google.com &> /dev/null; then
        success "Internetverbinding is beschikbaar."
    elif wget -q --spider http://google.com &> /dev/null; then
        success "Internetverbinding is beschikbaar."
    elif nc -zw1 google.com 443 &> /dev/null; then
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
    
    if get_yes_no "Wil je een backup maken van je bestaande dotfiles?"; then
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

# DEEL: GPU detectie en driver installatie
install_gpu_drivers() {
    section "GPU detectie en driver installatie"
    
    # Detecteer GPU
    log "GPU detecteren..."
    
    if lspci | grep -i nvidia &>/dev/null; then
        log "NVIDIA GPU gedetecteerd."
        if get_yes_no "Wil je NVIDIA drivers installeren?"; then
            log "NVIDIA drivers installeren..."
            sudo pacman -S --needed --noconfirm nvidia nvidia-utils nvidia-settings
            
            # Voeg Hyprland NVIDIA-specifieke configuratie toe
            echo -e "\n# NVIDIA-specifieke configuratie" >> "$HOME/.config/hypr/hyprland.conf"
            echo "env = LIBVA_DRIVER_NAME,nvidia" >> "$HOME/.config/hypr/hyprland.conf"
            echo "env = XDG_SESSION_TYPE,wayland" >> "$HOME/.config/hypr/hyprland.conf"
            echo "env = GBM_BACKEND,nvidia-drm" >> "$HOME/.config/hypr/hyprland.conf"
            echo "env = __GLX_VENDOR_LIBRARY_NAME,nvidia" >> "$HOME/.config/hypr/hyprland.conf"
            echo "env = WLR_NO_HARDWARE_CURSORS,1" >> "$HOME/.config/hypr/hyprland.conf"
            
            success "NVIDIA drivers geïnstalleerd en geconfigureerd."
        fi
    elif lspci | grep -i amd &>/dev/null; then
        log "AMD GPU gedetecteerd."
        if get_yes_no "Wil je AMD drivers installeren?"; then
            log "AMD drivers installeren..."
            sudo pacman -S --needed --noconfirm mesa lib32-mesa xf86-video-amdgpu vulkan-radeon lib32-vulkan-radeon
            success "AMD drivers geïnstalleerd."
        fi
    elif lspci | grep -i intel &>/dev/null; then
        log "Intel GPU gedetecteerd."
        if get_yes_no "Wil je Intel drivers installeren?"; then
            log "Intel drivers installeren..."
            sudo pacman -S --needed --noconfirm mesa lib32-mesa vulkan-intel lib32-vulkan-intel intel-media-driver
            success "Intel drivers geïnstalleerd."
        fi
    else
        warning "Geen bekende GPU gedetecteerd of GPU niet ondersteund."
        log "Je kunt handmatig drivers installeren voor je specifieke hardware."
    fi
    
    # Controleer op geïntegreerde GPU naast discrete GPU
    if lspci | grep -i "vga.*intel" &>/dev/null && lspci | grep -i "vga.*nvidia\|amd" &>/dev/null; then
        log "Geïntegreerde Intel GPU naast discrete GPU gedetecteerd."
        if get_yes_no "Wil je ook Intel iGPU drivers installeren?"; then
            log "Intel iGPU drivers installeren..."
            sudo pacman -S --needed --noconfirm mesa lib32-mesa vulkan-intel lib32-vulkan-intel intel-media-driver
            success "Intel iGPU drivers geïnstalleerd."
        fi
    fi
}

# DEEL 3: Repository instellen
setup_repository() {
    section "Dotfiles repository instellen"
    
    # Selecteer branch
    select_branch
    
    # Clone or update repository
    if [ -d "$DOTFILES_DIR" ]; then
        log "Dotfiles directory bestaat al, updating..."
        cd "$DOTFILES_DIR" || exit
        
        # Check if the branch exists remotely
        git fetch origin
        
        if git show-ref --verify --quiet "refs/remotes/origin/$DOTFILES_BRANCH"; then
            # Switch to the selected branch
            log "Overschakelen naar branch: $DOTFILES_BRANCH"
            git checkout $DOTFILES_BRANCH
            git pull origin $DOTFILES_BRANCH
        else
            error "Branch '$DOTFILES_BRANCH' bestaat niet in de remote repository."
            log "Beschikbare branches:"
            git branch -r | grep origin/ | grep -v HEAD | sed 's/origin\//  /'
            
            if get_yes_no "Wil je doorgaan met de huidige branch?"; then
                git pull
            else
                exit 1
            fi
        fi
        
        success "Dotfiles repository bijgewerkt naar branch: $DOTFILES_BRANCH"
    else
        log "Cloning dotfiles repository (branch: $DOTFILES_BRANCH)..."
        
        # Try to clone the specific branch
        if ! git clone --branch "$DOTFILES_BRANCH" "$DOTFILES_REPO" "$DOTFILES_DIR" 2>/dev/null; then
            error "Kon branch '$DOTFILES_BRANCH' niet clonen."
            
            # Ask if user wants to clone the default branch instead
            if get_yes_no "Wil je de standaard branch clonen?"; then
                if ! git clone "$DOTFILES_REPO" "$DOTFILES_DIR"; then
                    error "Dotfiles repository kon niet worden gecloned. Controleer de URL en je internetverbinding."
                    exit 1
                fi
                log "Standaard branch gecloned."
            else
                exit 1
            fi
        fi
        
        success "Dotfiles repository gecloned naar $DOTFILES_DIR (branch: $DOTFILES_BRANCH)"
    fi
    
    # Verify the repository structure
    if [ ! -d "$DOTFILES_DIR/.config" ]; then
        warning "De repository lijkt niet de verwachte structuur te hebben. Controleer of je de juiste repository gebruikt."
    else
        success "Repository structuur geverifieerd."
    fi
}

# DEEL 4: Kopieer configuratiebestanden
copy_config() {
    local source_path="$1"
    local target_path="$2"
    
    # Maak doeldirectory indien nodig
    mkdir -p "$(dirname "$target_path")"
    
    # Controleer of het doelpad al bestaat
    if [ -e "$target_path" ]; then
        # Maak een backup als het bestand/directory nog niet gebackupt is
        if [ ! -e "$BACKUP_DIR/$(basename "$target_path")" ]; then
            log "Backup maken van $target_path"
            cp -r "$target_path" "$BACKUP_DIR/$(basename "$target_path")"
        fi
        # Verwijder bestaand bestand/directory
        rm -rf "$target_path"
    fi
    
    # Kopieer de configuratie
    cp -r "$source_path" "$target_path"
    success "Gekopieerd: $source_path naar $target_path"
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
    sudo pacman -S --needed --noconfirm hyprland sddm waybar \
        qt6-wayland qt5-wayland \
        xdg-desktop-portal-hyprland \
        kitty rofi-wayland swaync\
        swww hypridle hyprlock\
        pavucontrol \
        brightnessctl grim slurp cliphist \
        polkit-kde-agent \
        ttf-jetbrains-mono-nerd ttf-font-awesome \
        nm-connection-editor blueman \
        nautilus \
        btop fastfetch \
    
    success "Hyprland en afhankelijkheden geïnstalleerd!"
}

# DEEL 6: Installeer dotfiles
install_dotfiles() {
    section "Dotfiles installeren"
    
    # Hyprland configuratie
    if [ -d "$DOTFILES_DIR/.config/hypr" ]; then
        copy_config "$DOTFILES_DIR/.config/hypr" "$HOME/.config/hypr"
    fi
    
    # Waybar configuratie
    if [ -d "$DOTFILES_DIR/.config/waybar" ]; then
        copy_config "$DOTFILES_DIR/.config/waybar" "$HOME/.config/waybar"
    fi
    
    # Rofi configuratie
    if [ -d "$DOTFILES_DIR/.config/rofi" ]; then
        copy_config "$DOTFILES_DIR/.config/rofi" "$HOME/.config/rofi"
    fi
    
    # Kitty configuratie
    if [ -d "$DOTFILES_DIR/.config/kitty" ]; then
        copy_config "$DOTFILES_DIR/.config/kitty" "$HOME/.config/kitty"
    fi
    
    # Swaylock configuratie
    if [ -d "$DOTFILES_DIR/.config/hyprlock" ]; then
        copy_config "$DOTFILES_DIR/.config/swaylock" "$HOME/.config/swaylock"
    fi
    
    # GTK thema configuratie
    if [ -d "$DOTFILES_DIR/.config/gtk-3.0" ]; then
        copy_config "$DOTFILES_DIR/.config/gtk-3.0" "$HOME/.config/gtk-3.0"
    fi
    
    # Shell configuratie
    if [ -f "$DOTFILES_DIR/.zshrc" ]; then
        copy_config "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
    fi
    if [ -f "$DOTFILES_DIR/.bashrc" ]; then
        copy_config "$DOTFILES_DIR/.bashrc" "$HOME/.bashrc"
    fi
    
    # Neovim configuratie
    if [ -d "$DOTFILES_DIR/.config/nvim" ]; then
        copy_config "$DOTFILES_DIR/.config/nvim" "$HOME/.config/nvim"
    fi
    
    # Wallpapers
    if [ -d "$DOTFILES_DIR/wallpapers" ]; then
        copy_config "$DOTFILES_DIR/wallpapers" "$HOME/wallpapers"
    fi
    
    # Scripts
    if [ -d "$DOTFILES_DIR/.local/bin" ]; then
        copy_config "$DOTFILES_DIR/.local/bin" "$HOME/.local/bin"
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

    # SDDM service
    log "SDDM service configureren..."
    sudo systemctl enable --now sddm.service
    sudo systemctl set-default graphical.target
    
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
        if get_yes_no "Wil je zsh als standaard shell instellen?"; then
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
    if get_yes_no "Wil je Hyprland en afhankelijkheden installeren?"; then
        install_dependencies
    fi
    
    # Installeer dotfiles
    install_dotfiles
    
    # Configureer services
    if get_yes_no "Wil je systemd services configureren?"; then
        configure_services
    fi

    # Installeer GPU drivers
    install_gpu_drivers
    
    # Configureer systeem
    configure_system
    
    # Afronden
    section "Installatie voltooid"
    success "Dotfiles installatie voltooid!"
    log "Backup van originele bestanden: $BACKUP_DIR"
    log "Je kunt nu uitloggen en Hyprland selecteren bij het inloggen."
    log "Of start Hyprland direct met het commando 'Hyprland'"
    
    # Vraag om herstart
    if get_yes_no "Wil je het systeem nu herstarten?"; then
        log "Systeem wordt herstart..."
        sudo reboot
    else
        log "Vergeet niet om later handmatig te herstarten voor de volledige werking."
    fi
}

# DEEL 11: Extra functies voor systeemonderhoud
system_maintenance() {
    section "Systeemonderhoud"
    
    if get_yes_no "Wil je systeemonderhoud uitvoeren?"; then
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
