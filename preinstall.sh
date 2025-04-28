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

# Tijdelijke directory voor de repository
TEMP_DIR="/tmp/breundotfiles_temp"

# Maak de tijdelijke directory aan
log "Tijdelijke directory aanmaken..."
rm -rf "$TEMP_DIR" 2>/dev/null
mkdir -p "$TEMP_DIR"

# Kloon de repository
log "Repository klonen..."
if git clone https://github.com/Breunder/Breundotfiles.git "$TEMP_DIR"; then
    success "Repository succesvol gekloond."
    
    # Ga naar de repository directory
    cd "$TEMP_DIR" || { error "Kan niet naar repository directory gaan."; exit 1; }
    
    # Maak het installatiescript uitvoerbaar
    log "Installatiescript uitvoerbaar maken..."
    chmod +x install.sh
    
    # Voer het installatiescript uit
    log "Installatiescript uitvoeren..."
    ./install.sh
    
    # Ga terug naar de oorspronkelijke directory
    cd - >/dev/null || { error "Kan niet terug naar oorspronkelijke directory."; exit 1; }
    
    # Verwijder de tijdelijke directory
    log "Tijdelijke repository opruimen..."
    rm -rf "$TEMP_DIR"
    success "Tijdelijke repository verwijderd."
else
    error "Kon de repository niet klonen. Controleer je internetverbinding en of de repository bestaat."
    exit 1
fi

success "Proces voltooid!"
