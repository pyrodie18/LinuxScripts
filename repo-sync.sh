#!/bin/bash
CENTOS_PATH="/Centos-Repo"
FEDORA_PATH="//Fedora-Repo/27"
MISC_PATH="/other-updates"
DRY_RUN=""

function usage()
{
	echo "Download Centos 7 Updates"
	echo ""
	echo -e "\t--cA   Download all Centos repos"
	echo -e "\t--cB   Download Centos base repo"
	echo -e "\t--cC   Download Centos CERT Forensics repo"
	echo -e "\t--cE   Download Centos epel repo"
	echo -e "\t--cU   Download Centos updates repo"
	echo -e "\t--cX   Download Centos eXtras repo"
	echo ""
	echo "Download Fedora 27 Updates"
	echo ""
	echo -e "\t--fA   Download all Fedora repos"
	echo -e "\t--fB   Download Fedora base repo"
	echo -e "\t--fC   Download Fedora CERT Forensics repo"
	echo -e "\t--fE   Download Fedora epel repo"
	echo -e "\t--fU   Download Fedora updates repo"
	echo ""
	echo "-t   Test Run (Does not actually download)"
	echo "-h or --help   Help"
}

while [ "$1" != "" ]; do
	PARAM=`echo $1 | awk -F= '{print $1}'`
	case $PARAM in
		-h | --help)
			usage
			exit
			;;
		-t)
			DRY_RUN="--dry-run"
			;;
		--cA)
			CENTOS_BASE=1
			CENTOS_EPEL=1
			CENTOS_UPDATES=1
			CENTOS_EXTRAS=1
			CENTOS_CERT=1
			;;
		--cB)
			CENTOS_BASE=1
			;;
		--cC)
			CENTOS_CERT=1
			;;
		--cE)
			CENTOS_EPEL=1
			;;
		--cU)
			CENTOS_UPDATES=1
			;;
		--cX)
			CENTOS_EXTRAS=1
			;;
		--fA)
			FEDORA_BASE=1
			FEDORA_CERT=1
			FEDORA_EPEL=1
			FEDORA_UPDATES=1

			;;
		--fB)
			FEDORA_BASE=1
			;;
		--fC)
			FEDORA_CERT=1
			;;
		--fE)
			FEDORA_EPEL=1
			;;
		--fU)
			FEDORA_UPDATES=1
			;;
		*)
			echo "ERROR:  Unknown paramater \"$PARAM\""
			usage
			exit 1
			;;
		esac
	shift
done

if [ "$CENTOS_BASE" = 1 ]; then
	rsync -avzi --progress $DRY_RUN --delete-after rsync://mirror.umd.edu/centos/7/os/x86_64/ $CENTOS_PATH/base
	CENTOS_BASE_EXIT=$?
	if [ "$CENTOS_BASE_EXIT" = 0 ]; then createrepo --update $CENTOS_PATH/base; fi
fi

if [ "$CENTOS_CERT" = 1 ]; then
	rsync -avzi --progress $DRY_RUN --delete-after --exclude='debug/*' rsync://linux-repository-rsync-server.cert.org/centos/cert/7/x86_64/ $CENTOS_PATH/cert
	CENTOS_CERT_EXIT=$?
fi

if [ "$CENTOS_EPEL" = 1 ]; then
	rsync -avzi --progress $DRY_RUN --delete-after --exclude='debug/*' rsync://mirrors.rit.edu/epel/7/x86_64/ $CENTOS_PATH/epel
	CENTOS_EPEL_EXIT=$?
	if [ "$CENTOS_EPEL_EXIT" = 0 ]; then createrepo --update $CENTOS_PATH/epel; fi
fi

if [ "$CENTOS_UPDATES" = 1 ]; then
	rsync -avzi --progress $DRY_RUN --delete-after rsync://mirror.umd.edu/centos/7/updates/x86_64/ $CENTOS_PATH/updates
	CENTOS_UPDATES_EXIT=$?
	if [ "$CENTOS_UPDATES_EXIT" = 0 ]; then createrepo --update $CENTOS_PATH/updates; fi
fi

if [ "$CENTOS_EXTRAS" = 1 ]; then
	rsync -avzi --progress $DRY_RUN --delete-after rsync://mirror.umd.edu/centos/7/extras/x86_64/ $CENTOS_PATH/extras
	CENTOS_EXTRAS_EXIT=$?
	if [ "$CENTOS_EXTRAS_EXIT" = 0 ]; then createrepo --update $CENTOS_PATH/extras; fi
fi

if [ "$FEDORA_BASE" = 1 ]; then
	rsync -avzi --progress $DRY_RUN --delete-after rsync://mirror.umd.edu/fedora/linux/releases/27/Everything/x86_64/ $FEDORA_PATH/base
	FEDORA_BASE_EXIT=$?
	if [ "$FEDORA_BASE_EXIT" = 0 ]; then createrepo --update $FEDORA_PATH/base/os; fi
fi

if [ "$FEDORA_CERT" = 1 ]; then
	rsync -avzi --progress $DRY_RUN --delete-after --exclude='SRPMS/' rsync://linux-repository-rsync-server.cert.org/fedora/cert/27/ $FEDORA_PATH/cert
	FEDORA_CERT_EXIT=$?
fi

if [ "$FEDORA_EPEL" = 1 ]; then
	rsync -avzi --progress $DRY_RUN --include="RPM-GPG-KEY-EPEL-7*" --exclude="*" rsync://mirror.umd.edu/fedora/epel/ $FEDORA_PATH/epel
	rsync -avzi --progress $DRY_RUN --delete-after --exclude='debug/*' rsync://mirror.umd.edu/fedora/epel/7/x86_64/ $FEDORA_PATH/epel
	FEDORA_EPEL_EXIT=$?
	if [ "$FEDORA_EPEL_EXIT" = 0 ]; then createrepo --update $FEDORA_PATH/epel; fi
fi

if [ "$FEDORA_UPDATES" = 1 ]; then
	rsync -avzi --progress $DRY_RUN --delete-after rsync://mirror.umd.edu/fedora/linux/updates/27/x86_64/ $FEDORA_PATH/updates
	FEDORA_UPDATES_EXIT=$?
	if [ "$FEDORA_UPDATES_EXIT" = 0 ]; then createrepo --update $FEDORA_PATH/updates; fi
fi

#Download other updates
echo "Updating misc files"

wget -P $MISC_PATH https://raw.githubusercontent.com/trisulnsm/trisul-scripts/master/lua/frontend_scripts/reassembly/ja3/prints/ja3fingerprint.json

wget -P $MISC_PATH http://database.clamav.net/main.cvd

wget -P $MISC_PATH http://database.clamav.net/daily.cvd

wget -P $MISC_PATH http://database.clamav.net/bytecode.cvd



# Check the results
if [ "$CENTOS_BASE" = 1 ]; then
	if [ "$CENTOS_BASE_EXIT" = 0 ]; then
		echo "The Centos base repo updated successfully"
	else
		echo "The Centos base repo failed to update and exited with a code of $CENTOS_BASE_EXIT"
	fi
fi

if [ "$CENTOS_CERT" = 1 ]; then
	if [ "$CENTOS_CERT_EXIT" = 0 ]; then
		echo "The Centos CERT repo updated successfully"
	else
		echo "The Centos CERT repo failed to update and exited with a code of $CENTOS_CERT_EXIT"
	fi
fi

if [ "$CENTOS_EPEL" = 1 ]; then
	if [ "$CENTOS_EPEL_EXIT" = 0 ]; then
		echo "The Centos epel repo updated successfully"
	else
		echo "The Centos epel repo failed to update and exited with a code of $CENTOS_EPEL_EXIT"
	fi
fi

if [ "$CENTOS_UPDATES" = 1 ]; then
	if [ "$CENTOS_UPDATES_EXIT" = 0 ]; then
		echo "The Centos updates repo updated successfully"
	else
		echo "The Centos updates repo failed to update and exited with a code of $CENTOS_UPDATES_EXIT"
	fi
fi

if [ "$CENTOS_EXTRAS" = 1 ]; then
	if [ "$CENTOS_EXTRAS_EXIT" = 0 ]; then
		echo "The Centos extras repo updated successfully"
	else
		echo "The Centos extras repo failed to update and exited with a code of $CENTOS_EXTRAS_EXIT"
	fi
fi

if [ "$FEDORA_BASE" = 1 ]; then
	if [ "$FEDORA_BASE_EXIT" = 0 ]; then
		echo "The Fedora base repo updated successfully"
	else
		echo "The Fedora base repo failed to update and exited with a code of $FEDORA_BASE_EXIT"
	fi
fi

if [ "$FEDORA_CERT" = 1 ]; then
	if [ "$FEDORA_CERT_EXIT" = 0 ]; then
		echo "The Fedora CERT repo updated successfully"
	else
		echo "The Fedora CERT repo failed to update and exited with a code of $FEDORA_CERT_EXIT"
	fi
fi

if [ "$FEDORA_EPEL" = 1 ]; then
	if [ "$FEDORA_EPEL_EXIT" = 0 ]; then
		echo "The Fedora epel repo updated successfully"
	else
		echo "The Fedora epel repo failed to update and exited with a code of $FEDORA_EPEL_EXIT"
	fi
fi

if [ "$FEDORA_UPDATES" = 1 ]; then
	if [ "$FEDORA_UPDATES_EXIT" = 0 ]; then
		echo "The Fedora updates repo updated successfully"
	else
		echo "The Fedora updates repo failed to update and exited with a code of $FEDORA_UPDATES_EXIT"
	fi
fi

echo "Repo Update has completed"
echo ""
echo ""
