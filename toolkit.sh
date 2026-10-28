#!/data/data/com.termux/files/usr/bin/bash

###############################################################################
# NetHunter Toolkit
# Main Menu
###############################################################################

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/config/version.conf"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/config/settings.conf"

###############################################################################
# Menu
###############################################################################

while true
do
    clear

    echo -e "${CYAN}"
    echo "============================================"
    echo "        NetHunter Toolkit"
    echo "============================================"
    echo -e "${RESET}"

    echo "Version : $TOOLKIT_VERSION"
    echo "Codename: $TOOLKIT_CODENAME"
    echo "Display : $DEFAULT_DISPLAY"
    echo "Auto Repair: $AUTO_REPAIR"
    echo "Auto Update: $AUTO_UPDATE"
    echo

    echo "1) Status"
    echo "2) Install / Verify"
    echo "3) Repair"
    echo "4) Update"
    echo "5) Backup"
    echo "6) Restore"
    echo "7) Cleanup"
    echo "8) Ubuntu GUI"
    echo "9) Exit" 

    echo
    read -r -p "Välj [1-8]: " CHOICE

    case "$CHOICE" in

        1)
            "$SCRIPT_DIR/status.sh"
            STATUS_CODE=$?

            if [[ "$AUTO_REPAIR" == "true" && "$STATUS_CODE" -eq 2 ]]; then
                echo
                info "Status rapporterade fel."
                info "AUTO_REPAIR är aktiverat. Startar repair..."

                if "$SCRIPT_DIR/repair.sh"; then
                    echo
                    info "Repair slutförd."
                else
                    echo
                    warn "Repair rapporterade ett problem."
                fi
            fi
            ;;

        2)
            if "$SCRIPT_DIR/install.sh"; then
                info "Installationen slutförd utan rapporterade problem."
            else
                INSTALL_STATUS=$?
                warn "Installationen misslyckades. Exit-kod: $INSTALL_STATUS"
            fi
            ;;

        3)
            if "$SCRIPT_DIR/repair.sh"; then
                info "Repair slutförd utan rapporterade problem."
            else
                REPAIR_STATUS=$?
                warn "Repair rapporterade ett problem. Exit-kod: $REPAIR_STATUS"
            fi
            ;;

        4)
            "$SCRIPT_DIR/update.sh"
            UPDATE_STATUS=$?

            echo

            case "$UPDATE_STATUS" in
                0)
                    info "Update slutförd utan rapporterade problem."
                    ;;
                1)
                    warn "Update slutförd, men verifieringen rapporterade ett problem."
                    ;;
                2)
                    warn "Update misslyckades."
                    ;;
                *)
                    warn "Update returnerade oväntad exit-kod: $UPDATE_STATUS"
                    ;;
            esac
            ;;

        5)
            if "$SCRIPT_DIR/backup.sh"; then
                info "Backup slutförd utan rapporterade problem."
            else
                BACKUP_STATUS=$?
                warn "Backup misslyckades. Exit-kod: $BACKUP_STATUS"
            fi
            ;;

        6)
            if "$SCRIPT_DIR/restore.sh"; then
                info "Restore slutförd utan rapporterade problem."
            else
                RESTORE_STATUS=$?
                warn "Restore rapporterade ett problem. Exit-kod: $RESTORE_STATUS"
            fi
            ;;

        7)
            if "$SCRIPT_DIR/cleanup.sh"; then
                info "Cleanup slutförd utan rapporterade problem."
            else
                CLEANUP_STATUS=$?
                warn "Cleanup rapporterade ett problem. Exit-kod: $CLEANUP_STATUS"
            fi
            ;;

        8)
            echo
            echo "============================================"
            echo "        UBUNTU GUI RUNTIME"
            echo "============================================"
            echo
            echo "1) Start"
            echo "2) Stop"
            echo "3) Restart"
            echo "4) Status"
            echo "5) Repair"
            echo "6) Tillbaka"
            echo

            read -r -p "Välj [1-6]: " GUI_CHOICE
            CONTROL_MODULE="$SCRIPT_DIR/modules/09-toolkit-control.sh"

            case "$GUI_CHOICE" in
                1)
                    "$CONTROL_MODULE" start
                    ;;
                2)
                    "$CONTROL_MODULE" stop
                    ;;
                3)
                    "$CONTROL_MODULE" restart
                    ;;
                4)
                    "$CONTROL_MODULE" state
                    ;;
                5)
                    "$CONTROL_MODULE" repair
                    ;;
                6)
                    ;;

                *)
                    warn "Ogiltigt GUI-val."
                    ;;
            esac
            ;;

        9)
            echo
            info "Avslutar NetHunter Toolkit."
            exit 0
            ;;

        *)
            echo
            warn "Ogiltigt val."
            ;;

    esac

    echo
    read -r -p "Tryck Enter för att återgå till menyn..."
done

