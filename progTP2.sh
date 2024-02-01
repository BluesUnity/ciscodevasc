#!/bin/bash
#ask ip csr
read -p "Entrez l'adresse IP pour CSR1kv: " ip
# Configuration des variables d'environnement pour le proxy
export http_proxy=http://cache.univ-pau.fr:3128
export https_proxy=$http_proxy
export noproxy=localhost,192.168.64.0/24

# Chemin du répertoire de travail
DIRECTORY="$HOME/labs/devnet-src/ansible/ansible-csr1000v"

# Assurer l'existence du répertoire ansible-csr1000v
if [ ! -d "$DIRECTORY" ]; then
    echo "Le répertoire $DIRECTORY n'existe pas. Création en cours..."
    mkdir -p "$DIRECTORY" || { echo "Erreur lors de la création du répertoire $DIRECTORY"; exit 1; }
fi

# Se déplacer dans le répertoire de travail
cd "$DIRECTORY" || { echo "Erreur lors de l'accès au répertoire $DIRECTORY"; exit 1; }

# Vérifier et créer le dossier backups si nécessaire
if [ ! -d "backups" ]; then
    echo "Création du dossier backups"
    mkdir backups || { echo "Erreur lors de la création du dossier backups"; exit 1; }
else
    echo "Le dossier backups existe déjà."
fi

# Affichage de la version d'Ansible
ansible --version || { echo "Erreur lors de l'exécution de ansible --version"; exit 1; }

# Configuration du fichier ansible.cfg
CONFIG_FILE="$DIRECTORY/ansible.cfg"
CONTENT="
# config file for ansible-csr1000v
[defaults]
inventory=./hosts
host_key_checking = False
retry_files_enabled = False
deprecation_warnings = False
"

# Vérification et ajout du contenu au fichier ansible.cfg si nécessaire
if ! grep -q "config file for ansible-csr1000v" "$CONFIG_FILE" 2>/dev/null; then
    echo "Ajout du contenu au fichier de configuration."
    echo "$CONTENT" > "$CONFIG_FILE" || { echo "Erreur lors de l'ajout du contenu à $CONFIG_FILE"; exit 1; }
else
    echo "Le contenu est déjà présent dans le fichier de configuration."
fi

# Création et configuration du fichier playbook si nécessaire
FILENAME="backup_cisco_router_playbook.yaml"
FILEPATH="$DIRECTORY/$FILENAME"
if [ ! -f "$FILEPATH" ]; then
    echo "Création du fichier $FILENAME avec le contenu spécifié."
    cat << EOF > "$FILEPATH"
---
- name: AUTOMATIC BACKUP OF RUNNING-CONFIG
  hosts: CSR1kv
  gather_facts: false
  connection: local
  tasks:
    - name: DISPLAYING THE RUNNING-CONFIG
      ios_command:
        commands:
          - show running-config
      register: config

    - name: SAVE OUTPUT TO ./backups/
      copy:
        content: "{{ config.stdout[0] }}"
        dest: "backups/show_run_{{ inventory_hostname }}.txt"
EOF
    [ $? -eq 0 ] || { echo "Erreur lors de la création du fichier $FILENAME"; exit 1; }
else
    echo "Le fichier $FILENAME existe déjà. Aucune action n'est effectuée."
fi

HOSTS_FILE="$DIRECTORY/hosts"
HOST_LINE="CSR1kv ansible_user=cisco ansible_password=cisco123! ansible_host=$ip"

if ! grep -q "$HOST_LINE" "$HOSTS_FILE" 2>/dev/null; then
    echo "Ajout de la configuration CSR1kv dans le fichier hosts."
    echo "$HOST_LINE" >> "$HOSTS_FILE"
else
    echo "La configuration CSR1kv existe déjà dans le fichier hosts."
fi

#install package 
pip install paramiko

# Exécuter la commande ansible-playbook si toutes les étapes précédentes ont réussi
echo "Exécution de ansible-playbook backup_cisco_router_playbook.yaml -i hosts"
ansible-playbook backup_cisco_router_playbook.yaml -i hosts || { echo "Erreur lors de l'exécution de ansible-playbook"; exit 1; }
