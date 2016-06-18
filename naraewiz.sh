#!/bin/bash
# Automated NaraeWiz ROM maker for G930K
#
# Important! You Have to set your OS to CONFIG! Default: Windows
#
if [ ! -e $1/build.prop ]; then
	echo "$(tput setaf 1)$(tput bold)Input /system directory path.$(tput sgr0)"
	exit 1
fi
if [ -e $1/framework/oat ]; then
	echo "$(tput setaf 1)$(tput bold)ROM is not properly deodex'ed!$(tput sgr0)"
	exit 1
fi

chmod 775 CONFIG
cat CONFIG | while read file; do
	export $file
done

SYSDIR=$1 # system dir
PREBUILTDIR=$(realpath _Prebuilt)
PATCHDIR=$(realpath _Patch)

ECHOINFO() {
	echo "$(tput bold) ::: $@ :::$(tput sgr0)"
}

ABORT() {
	echo "$(tput setaf 1)$(tput bold) !!! ERROR !!!$(tput sgr0)"
	exit 1
}

APPLY_PATCH() {
	echo "Applying patch $1"
	patch -p1 --forward --merge --no-backup-if-mismatch < $1
	if [ $? -ne 0 ]; then
		while read -p "$(tput setaf 1)$(tput bold)Patch failed, abort? (y/N)$(tput sgr0)" PATCH_CONTINUE; do
			case "$PATCH_CONTINUE" in
			Y | y )
				exit 1;;
			* )
				break;;
			esac
		done
	fi
}

read -p "$(tput bold)Make sure you entered the right directory path and press Enter to continue.$(tput sgr0)"

cd $SYSDIR

#
# NaraeWiz signature
#
sed -i -e 's/buildinfo.sh/buildinfo.sh\n# Powered by NaraeWiz!/g' build.prop

#
# Clean up unnecessary stuff
#
ECHOINFO "Removing spys"
cat remove.txt | while read file; do
	rm -rf $file
done
echo "Possible knox leftovers :"
find . -iname '*knox*' -exec echo {} \;

#
# Patch build.prop
#
ECHOINFO "Disabling securestorage"
sed -i 's/ro.securestorage.support=.*/ro.securestorage.support=false/' build.prop

#
# Prevent stock recovery restoration
#
ECHOINFO "Preventing stock recovery from being restored"
[ -e recovery-from-boot.p ] && mv recovery-from-boot.p recovery-from-boot.bak

#
# Replace bootanimation binary with that of CM so we can use *.zip instead of annoying *.qmg
#
ECHOINFO "Prepare for new bootanimations"
[ ! -e bin/bootanimation.bak ] && mv bin/bootanimation bin/bootanimation.bak

#
# Apply patches
#
ECHOINFO "Applying patches"
find $PATCHDIR -name '*.patch' | while read file; do APPLY_PATCH $file; done
find $PATCHDIR -name '*.sh' | while read file; do . $file; done

#
# Import prebuilts
#
ECHOINFO "Importing prebuilts"
ls -d $PREBUILTDIR/*/ | while read file; do cp -R $file/* ./; done

#
# Optimize framework : I need to find a zipalign binary that works on bash on windows first.
#

if [$HOST_OS = "Linux"]
then
	ECHOINFO "Optimizing framework files"
	find . -type f -name '*.jar' -maxdepth 1 | while read i; do 7z x $i -otest &>NUL; cd test; jar -cf0M $i *; zipalign -f 4 $i ../$i; cd ..; rm -r test; done
	find . -type f -name '*.apk' -maxdepth 1 | while read i; do 7z x $i -otest &>NUL; cd test; 7z a -tzip $i * -mx0 &>NUL; zipalign -f 4 $i ../$i; cd ..; rm -r test; done

fi
ECHOINFO "DONE."
