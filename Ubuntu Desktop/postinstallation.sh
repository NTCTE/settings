echo "Install some required packages..."
apt install -y software-properties-common apt-transport-https ca-certificates curl wget git mysql-client

echo "Install Google Chrome (stable)..."
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
dpkg -i --force-depends google-chrome-stable_current_amd64.deb
rm google-chrome-stable_current_amd64.deb

echo "Installing Visual Studio Code (stable)..."
wget -q https://packages.microsoft.com/keys/microsoft.asc -O- | sudo apt-key add -
add-apt-repository "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main"
apt update
apt install -y code

echo "Installing Atom (v1.59.0)..."
wget https://github.com/atom/atom/releases/download/v1.59.0/atom-amd64.deb
dpkg -i --force-depends atom-amd64.deb
rm atom-amd64.deb

echo "Installing and configure Docker..."
apt update
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
apt update
apt install docker-ce

echo "Installing InkScape (stable v1.1.2)"
add-apt-repository ppa:inkscape.dev/stable
apt update
apt install inkscape