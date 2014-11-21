<<SETUP

$ sudo groupadd sftp

$ sudo vim /etc/ssh/sshd_config

# override default of no subsystems
#Subsystem      sftp    /usr/libexec/openssh/sftp-server
Subsystem sftp internal-sftp
IgnoreRhosts yes
IgnoreUserKnownHosts no
PrintMotd yes
StrictModes yes
PubkeyAuthentication yes
RSAAuthentication yes
PermitEmptyPasswords no

Match Group sftp
  PasswordAuthentication no
  ChrootDirectory /chroot/%u/sftp
  X11Forwarding no
  AllowTcpForwarding no
  ForceCommand internal-sftp
  PubkeyAuthentication yes
  RSAAuthentication yes
  
$ sudo /etc/init.d/sshd restart

SETUP

# get the first argument as the client's username and do some validation
user=$1

if [ -z "$user" ]
then
    echo "Must supply a username"
    exit 1
fi

if getent passwd $user > /dev/null 2>&1;
then
    echo "User already exists"
    exit 1
fi

case "$user" in  
    *\ *)
        echo "Username cannot contain spaces"
        exit 1
        ;;
    *)
        echo "Creating user account for $user"
        ;;
esac

# get the paths we'll need
userhome="/chroot/$user"
sftphome="$userhome/sftp"
keydir="$userhome/.ssh"
keyfile="$keydir/$user.key"
authfile="$keydir/authorized_keys"

# add a user with no home dir
sudo useradd -MN -g sftp $user

echo "Making directories"
sudo mkdir -p $keydir
sudo mkdir -p $sftphome/imports/
sudo mkdir -p $sftphome/exports/

# create RSA key, if necessary
if [ -f "$keyfile" ]
then
    echo "$user already has an RSA key at $keyfile"
else
    echo "Creating RSA key"
    # 4096 bits with no passphrase
    sudo ssh-keygen -b 4096 -t rsa -f $keyfile -N "" -C $user
    sudo mv "$keyfile.pub" "$authfile"
fi

echo "Setting up permissions"
sudo chown -R root:root $userhome

sudo chown -R $user:sftp $keydir
sudo chmod 600 -R $keydir
sudo chmod 755 $keydir

sudo chown -R $user:sftp $sftphome/*

# set user's home dir
sudo usermod -d $userhome $user

# disable shell access
sudo usermod -s /sbin/nologin $user