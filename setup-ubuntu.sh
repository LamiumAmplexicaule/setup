#!/bin/bash
set -eu

echo "Install common tools."
sudo apt-get -qq update >/dev/null
sudo apt-get -qq -y upgrade >/dev/null
sudo apt-get -qq -y install git curl wget apt-transport-https gnupg lsb-release >/dev/null

echo "Install fzf, bat, fd"
sudo apt-get -qq -y install fzf bat fd-find >/dev/null
mkdir -p ~/.local/bin >/dev/null
ln -sf "$(which batcat)" ~/.local/bin/bat
ln -sf "$(which fdfind)" ~/.local/bin/fd
 
echo "Install fish."
sudo add-apt-repository -y ppa:fish-shell/release-3 >/dev/null
sudo apt-get -qq update >/dev/null
sudo apt-get -qq -y install fish >/dev/null
if [[ $(which fish) ]]; then
    mkdir -p ~/.config/fish/ >/dev/null
    cp -n config-linux.fish ~/.config/fish/config.fish >/dev/null
    fish -c "curl -sL https://git.io/fisher | source && fisher install jorgebucaran/fisher" >/dev/null
    fish -c "fisher install jethrokuan/z" >/dev/null
    fish -c "fisher install PatrickF1/fzf.fish" >/dev/null
fi

echo "Install hyper terminal"
wget -qO hyper.deb https://releases.hyper.is/download/deb
sudo apt-get -qq -y install ./hyper.deb >/dev/null
rm -f hyper.deb >/dev/null
if [[ $(which hyper) ]] && [[ ! -f ~/.hyper.js ]]; then
    cp -n .hyper.js ~/.hyper.js
    hyper i hyper-akari >/dev/null
    hyper i hyper-tab-icons-plus >/dev/null
    hyper i hyper-statusline >/dev/null
    hyper i hyperlinks >/dev/null
    hyper i hypercwd >/dev/null
fi

echo "Install tools for gpu."
GPU=$(lspci | grep VGA | cut -d ":" -f3)
OS_VERSION=$(lsb_release -rs)
KERNEL_VERSION=$(uname -r)
if [[ $GPU == *NVIDIA* ]]; then
    result=0
    output=$(dpkg -s | grep -e "cuda" >/dev/null) || result=$?
    if [[ $result == 0 ]]; then
        sudo apt-get -qq -y remove cuda >/dev/null
        sudo rm -rf /usr/local/cuda*
    fi

    echo "Install cuda."
    case $OS_VERSION in 
        22.04)
            wget -q https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-ubuntu2204.pin >/dev/null
            sudo mv cuda-ubuntu2204.pin /etc/apt/preferences.d/cuda-repository-pin-600 >/dev/null
            sudo apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/3bf863cc.pub >/dev/null
            sudo add-apt-repository -y "deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/ /" >/dev/null
            ;;
        20.04)
            wget -q https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-ubuntu2004.pin
            sudo mv cuda-ubuntu2004.pin /etc/apt/preferences.d/cuda-repository-pin-600
            sudo apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/3bf863cc.pub >/dev/null
            sudo add-apt-repository -y "deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/ /" >/dev/null
            ;;
        18.04)
            wget -q https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/cuda-ubuntu1804.pin
            sudo mv cuda-ubuntu1804.pin /etc/apt/preferences.d/cuda-repository-pin-600
            sudo apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/3bf863cc.pub >/dev/null
            sudo add-apt-repository -y "deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/ /" >/dev/null
            ;;
    esac

    sudo apt-get -qq update >/dev/null
    sudo apt-get -qq -y install cuda >/dev/null
elif [[ $GPU == *Advanced* ]]; then
    if [[ $OS_VERSION == 20.04 ]] || [[ $OS_VERSION == 18.04 ]]; then
        if [[ $KERNEL_VERSION == 5.4.* ]] || [[ $KERNEL_VERSION == 5.8.* ]]; then
            result=0
            output=$(dpkg -s | grep -e "amdgpu-dkms" >/dev/null) || result=$?
            if [[ $result == 0 ]]; then
                sudo amdgpu-uninstall >/dev/null
            fi

            # Install rocm
            echo "Install rocm."
            sudo apt-get -qq update >/dev/null
            (echo 'ADD_EXTRA_GROUPS=1' | sudo tee -a /etc/adduser.conf) >/dev/null
            (echo 'EXTRA_GROUPS=video' | sudo tee -a /etc/adduser.conf) >/dev/null
            (echo 'EXTRA_GROUPS=render' | sudo tee -a /etc/adduser.conf) >/dev/null
            sudo usermod -aG video "$LOGNAME" >/dev/null
            sudo usermod -aG render "$LOGNAME" >/dev/null
            wget -qO amdgpu-install_all.deb https://repo.radeon.com/amdgpu-install/22.10.1/ubuntu/focal/amdgpu-install_22.10.1.50101-1_all.deb >/dev/null
            sudo apt-get install ./amdgpu-install_all.deb >/dev/null
            sudo apt-get -qq update >/dev/null
            sudo amdgpu-install --usecase=rocm
        else
            echo "ROCm is only supported in 5.4 or 5.8."
            echo "ROCm installation will be skipped."
        fi
    fi
fi

echo "Install rust."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y &>/dev/null

echo "Install eclipse adoptium jdk."
(wget -O - https://packages.adoptium.net/artifactory/api/gpg/key/public | sudo tee /usr/share/keyrings/adoptium.asc) >/dev/null
(echo "deb [signed-by=/usr/share/keyrings/adoptium.asc] https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" | sudo tee /etc/apt/sources.list.d/adoptium.list) >/dev/null
sudo apt-get -qq update >/dev/null
sudo apt-get -qq install temurin-17-jdk >/dev/null

echo "Install firefox developer edition."
lang=$(echo LANG | cut -d "." -f 1)
user=$(whoami)
if [[ $lang != ja_JP ]]; then
    lang="en-US"
else
    lang="ja"
fi
wget -qO firefox-dev.tar.bz2 "https://download.mozilla.org/?product=firefox-devedition-latest-ssl&os=linux64&lang=$lang"
mkdir -p firefox-dev && tar -xjf firefox-dev.tar.bz2 -C firefox-dev --strip-components 1
mkdir -p /home/"$user"/.local/opt
mv firefox-dev /home/"$user"/.local/opt
(echo -e "[Desktop Entry]
Name=Firefox Developer Edition
GenericName=Web Browser
Exec=/home/$user/.local/opt/firefox-dev/firefox %u
Icon=/opt/firefox-dev/browser/chrome/icons/default/default128.png
Terminal=false
X-MultipleArgs=false
Type=Application
MimeType=text/html;text/xml;application/xhtml+xml;application/xml;application/rss+xml;application/rdf+xml;image/gif;image/jpeg;image/png;x-scheme-handler/http;x-scheme-handler/https;x-scheme-handler/ftp;x-scheme-handler/chrome;video/webm;application/x-xpinstall;
StartupNotify=true
Categories=Network;WebBrowser;Favorite;
Keywords=web;browser;internet;
Actions=new-window;new-private-window;
StartupWMClass=Firefox Developer Edition
[Desktop Action new-window]
Name=Open a New Window
Exec=/home/$user/.local/opt/firefox-dev/firefox %u
[Desktop Action new-private-window]
Name=Open a New Private Window
Exec=/home/$user/.local/opt/firefox-dev/firefox --private-window %u" | sudo tee -a /usr/share/applications/firefox-dev.desktop) >/dev/null
rm -f firefox-dev.tar.bz2

echo "Install google chrome."
wget -qO google-chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo apt-get -qq -y install ./google-chrome.deb >/dev/null
rm -f google-chrome.deb

echo "Install jetbrains toolbox."
wget -qO jetbrains-toolbox.tar.gz "https://data.services.jetbrains.com/products/download?platform=linux&code=TBA"
mkdir -p jetbrains-toolbox && tar -xzf jetbrains-toolbox.tar.gz -C jetbrains-toolbox --strip-components 1
./jetbrains-toolbox/jetbrains-toolbox
rm -rf jetbrains-toolbox && rm -f jetbrains-toolbox.tar.gz

echo "Install ulauncher."
sudo add-apt-repository -y ppa:agornostal/ulauncher >/dev/null
sudo apt-get -qq update >/dev/null
sudo apt-get -qq -y install ulauncher >/dev/null

echo "Install 1password."
(curl -sS https://downloads.1password.com/linux/keys/1password.asc | sudo gpg -q --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg) >/dev/null
(echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/amd64 stable main' | sudo tee /etc/apt/sources.list.d/1password.list) >/dev/null
sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22/ >/dev/null
(curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol | sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol) >/dev/null
sudo mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22 >/dev/null
(curl -sS https://downloads.1password.com/linux/keys/1password.asc | sudo gpg -q --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg) >/dev/null
sudo apt-get -qq update >/dev/null
sudo apt-get -qq -y install 1password >/dev/null

echo "Finishup."
sudo apt-get -qq clean >/dev/null
echo "Change default shell to $(which fish)"
chsh -s "$(which fish)"
