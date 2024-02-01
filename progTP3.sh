#!/bin/bash
# Demande de l'adresse IP pour CSR1kv
read -p "Entrez l'adresse IP pour CSR1kv: " ip

# Configuration des variables d'environnement pour le proxy
export http_proxy=http://cache.univ-pau.fr:3128
export https_proxy=$http_proxy
export noproxy=localhost,192.168.64.0/24
export noproxy=localhost,192.0.2.0/24


# Activation du serveur SSH
echo "Démarrage du serveur SSH..."
sudo systemctl start ssh

# Chemin du répertoire de travail ansible-apache
DIRECTORY="$HOME/labs/devnet-src/ansible/ansible-apache"

# Assurer l'existence du répertoire ansible-apache
if [ ! -d "$DIRECTORY" ]; then
    echo "Le répertoire $DIRECTORY n'existe pas. Création en cours..."
    mkdir -p "$DIRECTORY" || { echo "Erreur lors de la création du répertoire $DIRECTORY"; exit 1; }
fi

# Modification du fichier de stock Ansible (hosts)
HOSTS_FILE="$DIRECTORY/hosts"
echo "[webservers]
192.0.2.3 ansible_ssh_user=devasc ansible_ssh_pass=Cisco123!" > "$HOSTS_FILE"

# Modification du fichier ansible.cfg
CONFIG_FILE="$DIRECTORY/ansible.cfg"
echo "[defaults]
inventory=./hosts
host_key_checking = False
retry_files_enabled = False" > "$CONFIG_FILE"

# Vérification des communications avec le serveur Web local via le module ping Ansible
echo "Vérification de la communication avec le serveur Web..."
ansible webservers -m ping

# Modification des fichiers pour écouter sur le port 8081 et redémarrage d'Apache si nécessaire (dans un playbook Ansible)
PLAYBOOK_FILE="$DIRECTORY/install_apache_playbook.yaml"
cat << EOF > "$PLAYBOOK_FILE"
---
- hosts: webservers
  become: yes
  tasks:
  - name: INSTALL APACHE2
    apt: name=apache2 update_cache=yes state=latest
  - name: ENABLED MOD_REWRITE
    apache2_module: name=rewrite state=present
    notify:
    - RESTART APACHE2
  - name: APACHE2 LISTEN ON PORT 8081
    lineinfile: dest=/etc/apache2/ports.conf regexp="^Listen 80" line="Listen 8081" state=present
    notify:
    - RESTART APACHE2
  - name: APACHE2 VIRTUALHOST ON PORT 8081
    lineinfile: dest=/etc/apache2/sites-available/000-default.conf regexp="^<VirtualHost \*:80>" line="<VirtualHost *:8081>" state=present
    notify:
    - RESTART APACHE2
  handlers:
  - name: RESTART APACHE2
    service: name=apache2 state=restarted
EOF

# Exécution du playbook Ansible pour installer Apache avec les options spécifiées
ansible-playbook -v "$PLAYBOOK_FILE"


unset http_proxy
unset https_proxy
unset no_proxy

echo "
Listen 443
Listen  80
" >> /etc/apache2/ports.conf

#restart service apache2
echo "Vérification du statut d'Apache..."
sudo systemctl restart apache2
# Vérification que Apache a été installé et configuré correctement
echo "Vérification du statut d'Apache..."
sudo systemctl status apache2


# Indication pour accéder à la page web Apache par défaut via le navigateur
echo "Ouvrez votre navigateur à l'adresse http://$ip:8081 pour voir la page web Apache."
