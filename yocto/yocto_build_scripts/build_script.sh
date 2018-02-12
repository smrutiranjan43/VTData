#!/bin/bash
export SCRIPT_DIR=${PWD}

boardmenu(){
	clear
	exec 3>&1;
	result=$(dialog --backtitle "                                                                 YOCTO BUILD SCRIPT                "\
					 --checklist "Choose the Any One Board Name" 0 0 0 1 "BBB" off 2 "RPI3" off 2>&1 1>&3);
	exec 3>&-;
}
branchmenu(){
	clear
	exec 3>&1;
	result1=$( dialog --backtitle "                                                                  YOCTO BUILD SCRIPT                "\
					--checklist "Choose the Any One Branch Name" 0 0 0 1 "Rocko" off 2 "Pyro" off 3 "Morty" off  2>&1 1>&3);
	exec 3>&-;
}

settingsmenu(){
	clear
	exec 3>&1
        selection=$(dialog --backtitle "                                                                  YOCTO BUILD SCRIPT                "\
    	--title "Menu" \
    	--clear \
    	--cancel-label "Exit" \
    	--menu "Please select:" 0 0 4 \
    	"1" "Build Image" \
    	"2" "Create Bootable SDcard" \
    	"3" "Adding Packages" \
    	"4" "Adding Modules" \
    	2>&1 1>&3)
  	exec 3>&-
}

imagetype(){
	clear
	exec 3>&1
	imgres=$(dialog --backtitle "                                                                  YOCTO BUILD SCRIPT                "\
        --title "Menu" \
        --clear \
        --cancel-label "Exit" \
        --menu "Please select:" 0 0 4 \
        "1" "Console image" \
        "2" "qt5 image" \
        2>&1 1>&3)
        exec 3>&-
}

packagesmenu(){
	clear
	if [ -f .packagelist_$result ]
	then
		packages=$(cat .packagelist_$result)
	else
		packages=""
	fi
	exec 3>&1
	result2=$(dialog --backtitle "                                                                 YOCTO BUILD SCRIPT                "\
					--title "Packages" --clear --inputbox "Enter packages list with space separator\nMACRO : IMAGE_INSTALL_append " 16 51 "${packages}" 2>&1 1>&3)
	exec 3>&-
	echo $result2 > .packagelist_$result
}

modulesmenu(){
        clear
        if [ -f .modules_$result ]
        then
                modules=$(cat .modules_$result)
        else
                modules=""
        fi
        exec 3>&1
        modulesres=$(dialog --backtitle "                                                                 YOCTO BUILD SCRIPT                "\
                                        --title "Modules" --clear --inputbox "Enter Modules list with space separator\nMACRO : DISTRO_FEATURES_append " 16 51 "${modules}" 2>&1 1>&3)
        exec 3>&-
        echo $modulesres > .modules_$result
}

sdcardpart(){
        clear
        exec 3>&1
        sdcard=$(dialog --backtitle "                                                                 YOCTO BUILD SCRIPT                "\
                                        --title "SDCARD" --clear --inputbox "Enter the name of the sdcard\nExample : [ sdb ] or [ mmcblk0 ]  " 16 51 "sdb" 2>&1 1>&3)
        exec 3>&-
        echo $modulesres > .modules_$result
}


checkmainmenuoutput(){
	ret=0
	if ( echo "$result" | grep -q ' ' )  
	then
		dialog --title "Error" --msgbox 'Please Select One Board ' 6 30
		ret=1
	elif [ -z "$result" ]
	then
		ret=2
	else
		ret=0
	fi
	return $ret
}

checkbranchmenu(){
	ret1=0
	if ( echo "$result1" | grep -q ' ' )
	then
		dialog --title "Error" --msgbox 'Please Select One Branch ' 6 30
		ret1=1
	elif [ -z "$result1" ]
        then
                ret1=2
        else
                ret1=0
        fi

	return $ret1
}

mechainconfig(){
	case $result in 
		1 ) echo "MACHINE = \"beaglebone\"" >> .config
		;; 
		2 ) echo "MACHINE = \"raspberrypi3\"" >> .config
		;; 
	esac
	echo "DL_DIR = \"${SCRIPT_DIR}/oe-sources\"" >> .config
	echo "SSTATE_DIR = \"${SCRIPT_DIR}/sstate-cache\"" >> .config	
	echo "TMPDIR = \"${SCRIPT_DIR}/tmp-$BRANCH\"" >> .config
}

buildimage(){
	clear
	sudo apt-get install -y gawk wget git-core diffstat unzip texinfo gcc-multilib \
     	build-essential chrpath socat cpio python python3 python3-pip python3-pexpect \
     	xz-utils debianutils iputils-ping libsdl1.2-dev xterm ncurses-dev
	mechainconfig
	clear
	if [ ! -d "poky" ]
	then
        	git clone -b $BRANCH git://git.yoctoproject.org/poky.git poky
	else	
		cd poky
		git checkout $BRANCH
		cd ..
	fi
	if [ ! -d "poky/meta-openembedded" ]
	then
		git clone -b $BRANCH git://git.openembedded.org/meta-openembedded poky/meta-openembedded
	else	
		cd poky/meta-openembedded
                git checkout $BRANCH
		cd -
	fi
	if [ ! -d "poky/meta-qt5" ]
	then
		git clone -b $BRANCH https://github.com/meta-qt5/meta-qt5.git poky/meta-qt5
	else
                cd poky/meta-qt5
                git checkout $BRANCH
                cd -
	fi


	if [ $result -eq 1 ]
	then
		if [ ! -d "bbb" ]
		then
			mkdir bbb
		fi
		if [ ! -d "bbb/meta-bbb" ]
		then
			git clone -b $BRANCH git://github.com/jumpnow/meta-bbb bbb/meta-bbb
		else
                	cd bbb/meta-bbb
                	git checkout $BRANCH
                	cd -
		fi
		cd poky
		source ./oe-init-build-env ../bbb/build		
		cat ${SCRIPT_DIR}/bbb/meta-bbb/conf/local.conf.sample ${SCRIPT_DIR}/.config > conf/local.conf
		sed -i 's/jumpnowtek/raj/g' ${SCRIPT_DIR}/bbb/build/conf/local.conf
		if [ -f ${SCRIPT_DIR}/.packagelist_$result ]
		then
			echo 'IMAGE_INSTALL_append +=" '$(cat ${SCRIPT_DIR}/.packagelist_$result)'"' >> conf/local.conf
		fi
		if [ -f ${SCRIPT_DIR}/.modules_$result ]
		then
			echo 'DISTRO_FEATURES_append +=" '$(cat ${SCRIPT_DIR}/.modules_$result)'"' >> conf/local.conf
		fi
		if [ ! -f conf/bblayers.con ]
		then
			cp ${SCRIPT_DIR}/bbb/meta-bbb/conf/bblayers.conf.sample conf/bblayers.conf
			sed -i 's/${HOME}/${SCRIPT_DIR}/g' ${SCRIPT_DIR}/bbb/build/conf/bblayers.conf
			sed -i "s/poky-$BRANCH/poky/g" ${SCRIPT_DIR}/bbb/build/conf/bblayers.conf
			sed '3iSCRIPT_DIR = '\"${SCRIPT_DIR}\"'' ${SCRIPT_DIR}/bbb/build/conf/bblayers.conf > tmp
			mv tmp ${SCRIPT_DIR}/bbb/build/conf/bblayers.conf
		fi
	fi


	if [ $result -eq 2 ]
	then
		if [ ! -d "rpi" ]
		then
			mkdir rpi
		fi
		if [ ! -d "poky/meta-security" ]
		then
			git clone -b $BRANCH git://git.yoctoproject.org/meta-security poky/meta-security
		else
                	cd poky/meta-security
                	git checkout $BRANCH
                	cd -
		fi
		if [ ! -d "poky/meta-raspberrypi" ]
		then
			git clone -b $BRANCH git://git.yoctoproject.org/meta-raspberrypi poky/meta-raspberrypi
		else
	                cd poky/meta-raspberrypi
	                git checkout $BRANCH
	                cd -
		fi
		if [ ! -d "rpi/meta-rpi" ]
		then
			git clone -b $BRANCH git://github.com/jumpnow/meta-rpi rpi/meta-rpi
		else
                	cd rpi/meta-rpi
                	git checkout $BRANCH
                	cd -
		fi
		cd poky
		source ./oe-init-build-env ../rpi/build
		cat ${SCRIPT_DIR}/rpi/meta-rpi/conf/local.conf.sample ${SCRIPT_DIR}/.config > conf/local.conf
		sed -i 's/jumpnowtek/raj/g' ${SCRIPT_DIR}/rpi/build/conf/local.conf
		if [ -f ${SCRIPT_DIR}/.packagelist_$result ]
                then
			echo 'IMAGE_INSTALL_append +=" '$(cat ${SCRIPT_DIR}/.packagelist_$result)'"' >> conf/local.conf
		fi
		if [ -f ${SCRIPT_DIR}/.modules_$result ]
                then
			echo 'DISTRO_FEATURES_append +=" '$(cat ${SCRIPT_DIR}/.modules_$result)'"' >> conf/local.conf
		fi
		if [ ! -f conf/bblayers.conf ]
		then 
			cp ${SCRIPT_DIR}/rpi/meta-rpi/conf/bblayers.conf.sample  conf/bblayers.conf
			sed -i 's/${HOME}/${SCRIPT_DIR}/g' ${SCRIPT_DIR}/rpi/build/conf/bblayers.conf
			sed -i "s#poky-$BRANCH#poky#g" ${SCRIPT_DIR}/rpi/build/conf/bblayers.conf
			sed '3iSCRIPT_DIR = '\"${SCRIPT_DIR}\"'' ${SCRIPT_DIR}/rpi/build/conf/bblayers.conf > tmp
			mv tmp ${SCRIPT_DIR}/rpi/build/conf/bblayers.conf
		fi
	fi
	echo "IMAGE Type : $image"
	bitbake $image
}


creatingsdcard(){
	sdcardpart
	if [ $result -eq 1 ]
	then
		cd ${SCRIPT_DIR}/bbb/meta-bbb/scripts
		export MACHINE=beaglebone
		export OETMP=${SCRIPT_DIR}/tmp-$BRANCH
		sudo ./mk2parts.sh $sdcard
		if [ ! -d /media/card ]
		then
			sudo mkdir /media/card
		fi
		if [ ! -f uEnv.txt ]
		then
			cp uEnv.txt-example uEnv.txt
		fi
		./copy_boot.sh $sdcard
		./copy_rootfs.sh $sdcard console 

	fi
	if [ $result -eq 2 ]
	then
		cd ${SCRIPT_DIR}/rpi/meta-rpi/scripts
		export MACHINE=raspberrypi3
		export OETMP=${SCRIPT_DIR}/tmp-$BRANCH
	        sudo ./mk2parts.sh $sdcard
		if [ ! -d /media/card ]
		then
			sudo mkdir /media/card
		fi
		./copy_boot.sh $sdcard
		./copy_rootfs.sh $sdcard console
	fi
}

settingsconfig(){
        case $selection in
		0 )
	        clear
        	;;
        	1 )
        	imagetype
 		if [ -z "$imgres" ]	
		then 
			clear
			exit 1
		else
			if [ $imgres -eq 1 ]
			then
                		export image=console-image
				buildimage
                 	else
                 		export image=qt5-image
				buildimage
                 	fi
		fi
		;;
        	2 )
        	creatingsdcard
        	;;
        	3 )
		packagesmenu
		settingsmenu
		if [ -z "$selection" ]
        	then
			clear
        	        exit 1
        	else
        	        settingsconfig
        	fi        	
        	;;
        	4 )
        	modulesmenu
		settingsmenu
                if [ -z "$selection" ]
                then
                        clear
                        exit 1
                else
                        settingsconfig
                fi
                ;;
        esac
}

branchconfig(){
	case $result1 in
		 1 ) export BRANCH=rocko
		 ;;
		 2 ) export BRANCH=pyro
                 ;;
		 3 ) export BRANCH=morty
                 ;;
	esac
}

if [ -f ".config" ]
then
	rm .config
fi

boardmenu
checkmainmenuoutput
while [ $? -eq 1 ]
do
	boardmenu
	checkmainmenuoutput
done 

clear
if [ $ret -eq 0 ]
then
	branchmenu
	checkbranchmenu
	while [ $ret1 -eq 1 ]
	do
	        branchmenu
	        checkbranchmenu
	done
	if [ $ret1 -eq 0 ]
	then
        	branchconfig
	fi
	if [ $ret1 -eq 2 ]
	then
		export BRANCH=rocko
	fi
	
        settingsmenu
	if [ -z "$selection" ]
	then
		exit 1
	else
		settingsconfig
	fi
fi




