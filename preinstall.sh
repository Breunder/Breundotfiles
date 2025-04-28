#!/bin/bash

# Kleuren voor output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log functies
log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Directory voor de repository
REPO_DIR="$HOME/.breundotfiles"

# Maak de directory aan
log "Directory aanmaken..."
rm -rf "$REPO_DIR" 2>/dev/null
mkdir -p "$REPO_DIR"

# Kloon de repository
log "Repository klonen..."
if git clone https://github.com/Breunder/Breundotfiles.git "$REPO_DIR"; then
    success "Repository succesvol gekloond."
    
    # Ga naar de repository directory
    cd "$REPO_DIR" || { error "Kan niet naar repository directory gaan."; exit 1; }
    
    # Controleer of install.sh bestaat
    if [ ! -f "./install.sh" ]; then
        error "install.sh niet gevonden in de repository"
        log "Inhoud van de repository:"
        ls -la
        exit 1
    fi
    
    # Maak het installatiescript uitvoerbaar
    log "Installatiescript uitvoerbaar maken..."
    chmod +x ./install.sh
    
    # Voer het installatiescript uit met expliciete interactieve modus
    log "Installatiescript uitvoeren in interactieve modus..."
    bash -i ./install.sh
    
    # Ga terug naar de oorspronkelijke directory
    cd - >/dev/null || { error "Kan niet terug naar oorspronkelijke directory."; exit 1; }
    
    # Verwijder de repository directory
    log "Repository opruimen..."
    rm -rf "$REPO_DIR"
    success "Repository verwijderd."
else
    error "Kon de repository niet klonen. Controleer je internetverbinding en of de repository bestaat."
    exit 1
fi

success "Process voltooid!"