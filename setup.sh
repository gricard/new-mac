#!/bin/sh

#                    _           _        _ _ 
#  ___  _____  __   (_)_ __  ___| |_ __ _| | |
# / _ \/ __\ \/ /   | | '_ \/ __| __/ _` | | |
#| (_) \__ \>  <    | | | | \__ \ || (_| | | |
# \___/|___/_/\_\   |_|_| |_|___/\__\__,_|_|_|


echo "Setting things up just the way I like them..."

# Based on:
# https://github.com/nnja/new-computer
# Some configs reused from:
# https://github.com/ruyadorno/installme-osx/
# https://gist.github.com/millermedeiros/6615994
# https://gist.github.com/brandonb927/3195465/
# https://github.com/mjording/dotfiles/blob/master/osx

# Colorize

# Set the colours you can use
black=$(tput setaf 0)
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
blue=$(tput setaf 4)
magenta=$(tput setaf 5)
cyan=$(tput setaf 6)
white=$(tput setaf 7)

# Resets the style
reset=`tput sgr0`

# Color-echo. Improved. [Thanks @joaocunha]
# arg $1 = message
# arg $2 = Color
cecho() {
  echo "${2}${1}${reset}"
  return
}

echo ""
cecho "###############################################" $red
cecho "#        DO NOT RUN THIS SCRIPT BLINDLY       #" $red
cecho "#         YOU'LL PROBABLY REGRET IT...        #" $red
cecho "#                                             #" $red
cecho "#              READ IT THOROUGHLY             #" $red
cecho "#         AND EDIT TO SUIT YOUR NEEDS         #" $red
cecho "###############################################" $red
echo ""

# Set continue to false by default.
CONTINUE=false

echo ""
cecho "Have you read through the script you're about to run and " $red
cecho "understood that it will make changes to your computer? (y/n)" $red
read -r response
if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]; then
  CONTINUE=true
fi

if ! $CONTINUE; then
  # Check if we're continuing and output a message if not
  cecho "Please go read the script, it only takes a few minutes" $red
  exit
fi

# Here we go.. ask for the administrator password upfront and run a
# keep-alive to update existing `sudo` time stamp until script has finished
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &


##############################
# General
##############################

# Set computer name (as done via System Preferences → Sharing)
read -p 'Name this computer: ' hostName
sudo scutil --set ComputerName $hostName
sudo scutil --set HostName $hostName
sudo scutil --set LocalHostName $hostName
sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName -string $hostName

# Menu bar: show remaining battery time (on pre-10.8); hide percentage
defaults write com.apple.menuextra.battery ShowPercent -string "YES"
#defaults write com.apple.menuextra.battery ShowTime -string "YES"

##############################
# Prerequisite: Install Brew #
##############################

echo "Installing brew..."

if test ! $(which brew)
then
	## Don't prompt for confirmation when installing homebrew
  /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)" < /dev/null
fi

# Latest brew, install brew cask
brew upgrade
brew update
brew tap caskroom/cask


#############################################
### Generate ssh keys & add to ssh-agent
### See: https://help.github.com/articles/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent/
#############################################

echo "Generating ssh keys, adding to ssh-agent..."
read -p 'Input email for ssh key: ' useremail

echo "Use default ssh file location, enter a passphrase: "
ssh-keygen -t rsa -b 4096 -C "$useremail"  # will prompt for password
eval "$(ssh-agent -s)"

# Now that sshconfig is synced add key to ssh-agent and
# store passphrase in keychain
ssh-add -K ~/.ssh/id_rsa

# If you're using macOS Sierra 10.12.2 or later, you will need to modify your ~/.ssh/config file to automatically load keys into the ssh-agent and store passphrases in your keychain.

if [ -e ~/.ssh/config ]
then
    echo "ssh config already exists. Skipping adding osx specific settings... "
else
	echo "Writing osx specific settings to ssh config... "
   cat <<EOT >> ~/.ssh/config
	Host *
		AddKeysToAgent yes
		UseKeychain yes
		IdentityFile ~/.ssh/id_rsa
EOT
fi

#############################################
### Add ssh-key to GitHub via api
#############################################

echo "Adding ssh-key to GitHub (via api)..."
echo "Important! For this step, use a github personal token with the admin:public_key permission."
echo "If you don't have one, create it here: https://github.com/settings/tokens/new"

retries=3
SSH_KEY=`cat ~/.ssh/id_rsa.pub`

for ((i=0; i<retries; i++)); do
      read -p 'GitHub username: ' ghusername
      read -sp 'GitHub personal token: ' ghtoken

      gh_status_code=$(curl -o /dev/null -s -w "%{http_code}\n" -u "$ghusername:$ghtoken" -d '{"title":"'$hostName'","key":"'"$SSH_KEY"'"}' 'https://api.github.com/user/keys')

      if (( $gh_status_code -eq == 201))
      then
          echo "GitHub ssh key added successfully!"
          break
      else
			echo "Something went wrong. Enter your credentials and try again..."
     		echo -n "Status code returned: "
     		echo $gh_status_code
      fi
done

[[ $retries -eq i ]] && echo "Adding ssh-key to GitHub failed! Try again later."

#############################################
### Setup git user info
#############################################
read -p 'Git email address: ' gitEmail
read -p 'Git name: ' gitName
git config --global user.email "$gitEmail"
git config --global user.name "$gitName"

##############################
# Install via Brew           #
##############################

echo "Starting brew app install..."

### Developer Tools
brew cask install iterm2
brew install node
brew install yarn


### Command line tools - install new ones, update others to latest version
brew install git  # upgrade to latest
brew install tmux
#brew link curl --force
brew install trash  # move to osx trash instead of rm
brew install less

### Dev Editors 
brew cask install visual-studio-code
#brew cask install phpstorm #installs 2018.x

### Productivity
brew cask install google-chrome
brew cask install firefox
brew cask install alfred
brew cask install dropbox
brew cask install spectacle


### Quicklook plugins https://github.com/sindresorhus/quick-look-plugins
brew cask install qlcolorcode # syntax highlighting in preview
brew cask install qlstephen  # preview plaintext files without extension
brew cask install qlmarkdown  # preview markdown files
brew cask install quicklook-json  # preview json files
brew cask install epubquicklook  # preview epubs, make nice icons
brew cask install quicklook-csv  # preview csvs

### Run Brew Cleanup
brew cleanup


### Fix Dock
brew install dockutil
dockutil --remove Mail --no-restart
dockutil --remove Siri --no-restart
dockutil --remove Launchpad --no-restart
dockutil --remove Contacts --no-restart
dockutil --remove Calendar --no-restart
dockutil --remove Notes --no-restart
dockutil --remove Reminders --no-restart
dockutil --remove Maps --no-restart
dockutil --remove Photos --no-restart
dockutil --remove Messages --no-restart
dockutil --remove FaceTime --no-restart
dockutil --remove News --no-restart
dockutil --remove iTunes --no-restart
dockutil --remove App\ Store --no-restart
dockutil --add /Applications/Google\ Chrome.app --after Safari --no-restart
dockutil --add /Applications/Firefox.app --after Google\ Chrome --no-restart
dockutil --add /Applications/Visual\ Studio\ Code.app --after Firefox --no-restart
dockutil --add /Applications/Utilities/Terminal.app --after Firefox --no-restart
dockutil --add /Applications/iTerm.app --after Terminal --no-restart
dockutil --add /Applications/Utilities/Disk\ Utility.app --after Terminal --no-restart
dockutil --add /Applications/Utilities/Activity\ Monitor.app --after Diskutil
### make sure the last dockutil call does not have --no-restart

#############################################
### Installs from Mac App Store
#############################################

#echo "Installing apps from the App Store..."

### find app ids with: mas search "app name"
#brew install mas

### Mas login is currently broken on mojave. See:
### Login manually for now.

#cecho "Need to log in to App Store manually to install apps with mas...." $red
#echo "Opening App Store. Please login."
#open "/Applications/App Store.app"
#echo "Is app store login complete.(y/n)? "
#read response
#if [ "$response" != "${response#[Yy]}" ]
#then
#	mas install 907364780  # Tomato One - Pomodoro timer
#	mas install 485812721  # Tweetdeck
#	mas install 668208984  # GIPHY Capture. The GIF Maker (For recording my screen as gif)
#	mas install 1351639930 # Gifski, convert videos to gifs
#	mas install 414030210  # Limechat, IRC app.
#else
#	cecho "App Store login not complete. Skipping installing App Store Apps" $red
#fi


#############################################
### Set OSX Preferences - Borrowed from https://github.com/mathiasbynens/dotfiles/blob/master/.macos
#############################################

# Close any open System Preferences panes, to prevent them from overriding
# settings we’re about to change
osascript -e 'tell application "System Preferences" to quit'

###############################################################################
# Finder, Dock, & Menu Items                                                  #
###############################################################################

# Finder: allow quitting via ⌘ + Q; doing so will also hide desktop icons
defaults write com.apple.finder QuitMenuItem -bool true

# Expand save panel by default
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

# Save to disk (not to iCloud) by default
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

# Finder: show all filename extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Finder: show hard drives on desktop
defaults write com.apple.finder ShowHardDrivesOnDesktop -int 1

# Shrink dock icons
defaults write com.apple.dock tilesize -int 45

# Display full POSIX path as Finder window title
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

# Disable the warning when changing a file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Automatically quit printer app once the print jobs complete
defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true

# Disable the “Are you sure you want to open this application?” dialog
#defaults write com.apple.LaunchServices LSQuarantine -bool false

# Avoid creating .DS_Store files on network or USB volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Use list view in all Finder windows by default
# Four-letter codes for the other view modes: `icnv`, `clmv`, `Flwv`
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# Minimize windows into their application’s icon
defaults write com.apple.dock minimize-to-application -bool true

# Don’t show recent applications in Dock
defaults write com.apple.dock show-recents -bool false

# Avoid creating .DS_Store files on network volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true

# Show the ~/Library folder
chflags nohidden ~/Library

# Finder: show hidden files by default
defaults write com.apple.finder AppleShowAllFiles -bool true

# Finder: allow text selection in Quick Look
defaults write com.apple.finder QLEnableTextSelection -bool true

# Enable snap-to-grid for icons on the desktop and in other icon views
/usr/libexec/PlistBuddy -c "Set :DesktopViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist
/usr/libexec/PlistBuddy -c "Set :FK_StandardViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist
/usr/libexec/PlistBuddy -c "Set :StandardViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist

# Remove cmd-space shortcut from Spotlight so we can use it for Alfred
/usr/libexec/PlistBuddy ~/Library/Preferences/com.apple.symbolichotkeys.plist -c "Set AppleSymbolicHotKeys:64:enabled false"

# turn off the finder search shortcut also
#/usr/libexec/PlistBuddy ~/Library/Preferences/com.apple.symbolichotkeys.plist -c "Set AppleSymbolicHotKeys:65:enabled false"

# start spectacle on login (find a way to do this, it doesn't work)
osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/Spectacle.app", hidden:false}'


###############################################################################
# Safari & WebKit                                                             #
###############################################################################

# Set Safari’s home page to `about:blank` for faster loading
defaults write com.apple.Safari HomePage -string "about:blank"

# Prevent Safari from opening ‘safe’ files automatically after downloading
defaults write com.apple.Safari AutoOpenSafeDownloads -bool false

# Hide Safari’s bookmarks bar by default
defaults write com.apple.Safari ShowFavoritesBar -bool false

# Enable Safari’s debug menu
#defaults write com.apple.Safari IncludeInternalDebugMenu -bool true

# Enable the Develop menu and the Web Inspector in Safari
defaults write com.apple.Safari IncludeDevelopMenu -bool true
defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled -bool true

###############################################################################
# Time Machine                                                                #
###############################################################################

# Prevent Time Machine from prompting to use new hard drives as backup volume
defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

##################
### Text Editing / Keyboards
##################

# Disable smart quotes and smart dashes
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false

# Disable auto-correct
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# Use plain text mode for new TextEdit documents
defaults write com.apple.TextEdit RichText -int 0

# Open and save files as UTF-8 in TextEdit
defaults write com.apple.TextEdit PlainTextEncoding -int 4
defaults write com.apple.TextEdit PlainTextEncodingForWrite -int 4

###############################################################################
# Screenshots / Screen                                                        #
###############################################################################

# Require password immediately after sleep or screen saver begins"
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0

###############################################################################
# Trackpad, mouse, keyboard, Bluetooth accessories, and input                 #
###############################################################################

# Disable “natural” (Lion-style) scrolling
# Uncomment if you don't use scroll reverser
defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false

# Stop iTunes from responding to the keyboard media keys
launchctl unload -w /System/Library/LaunchAgents/com.apple.rcd.plist 2> /dev/null

# Enable full keyboard access for all controls
# (e.g. enable Tab in modal dialogs)
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

# Set key repeat rate to fast
defaults write NSGlobalDomain KeyRepeat -int 2

# Reduce delay to repeat
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# Increase trackpad speed
defaults write NSGlobalDomain com.apple.trackpad.scaling -int 2.5

# Turn off trackpad click noise
defaults write com.apple.AppleMultitouchTrackpad ActuationStrength -int 1

# Disabling press-and-hold for special keys in favor of key repeat
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# Turn off keyboard illumination when computer is not used for 5 minutes
defaults write com.apple.BezelServices kDimTime -int 300


###############################################################################
# Mac App Store                                                               #
###############################################################################

# Enable the automatic update check
defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true

# Download newly available updates in background
defaults write com.apple.SoftwareUpdate AutomaticDownload -int 1

# Install System data files & security updates
defaults write com.apple.SoftwareUpdate CriticalUpdateInstall -int 1

###############################################################################
# Photos                                                                      #
###############################################################################

# Prevent Photos from opening automatically when devices are plugged in
defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true

###############################################################################
# Google Chrome                                                               #
###############################################################################

# Disable the all too sensitive backswipe on trackpads
defaults write com.google.Chrome AppleEnableSwipeNavigateWithScrolls -bool false

###############################################################################
# Terminal                                                                    #
###############################################################################

# Enable option as meta key
# This does not seem to work. set doesn't work either
/usr/libexec/PlistBuddy -c "add :Window\ Settings:Basic:useOptionAsMetaKey bool true" ~/Library/Preferences/com.apple.Terminal.plist

###############################################################################
# Energy settings                                                             #
###############################################################################

# turn display off after 10 minutes on battery
sudo pmset displaysleep 10

# go to sleep after 20 minutes on battery
sudo pmset sleep 20

# go to sleep after an hour when plugged in
sudo systemsetup -setsleep 60

# put display to sleep after 10 minutes when plugged in
sudo systemsetup -setdisplaysleep 10


#############################################
### Install dotfiles repo
#############################################
# dotfiles for vs code, emacs, gitconfig, oh my zsh, etc. 
# git clone git@github.com:gricard/dotfiles.git
# cd dotfiles

echo ""
echo "Done!" $cyan
echo
echo
echo "Additional manual setup (for now):"
echo " - adjust the screen resolution manually (for now)"
echo " - turn on 'Use option as meta key' in Terminal"
echo " - enable full disk access, etc. for iTerm"
echo " - install the Sync Settings VS Code extension and connect to your gist!"
echo " - download phpstorm 2017.1: https://confluence.jetbrains.com/display/PhpStorm/Previous+PhpStorm+Releases"
echo "   - don't modify the bin/phpstorm.vmoptions memory usage settings until after you open it once or it gets corrupted!"
echo " - set alfred to use cmd-space in prefs, and to enable accessibility controls & full disk access"
echo " - enable start at login for spectacle"
echo
echo ""
echo ""
cecho "################################################################################" $white
echo ""
echo ""
cecho "Note that some of these changes require a logout/restart to take effect." $red
echo ""
echo ""
echo -n "Check for and install available OSX updates, install, and automatically restart? (y/n)? "
read response
if [ "$response" != "${response#[Yy]}" ] ;then
    softwareupdate -i -a --restart
fi