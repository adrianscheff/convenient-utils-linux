#!/bin/bash
# How much space a user occupies in dir

tmp_du_exe=
help(){
	echo -e "Usage: $0  [-u <username>] [-d <dirname>] [-k] [-s]\n"
	echo -e "Example command: \n'$0 -u someuser -d /home/someuser -s'\n"
	echo -e "Available options: \n
		-u  Username for which to calculate space usage. Default current user.
		-d  Dir to perform analysis. Default '.'
		-k  Show in Kibibytes without any unit of measure (like 'du'). By default it will show something like '1.5 MiB'
		-s  Force silent (no verbose). Default OFF.
		-h  Help
		" 
	}

user_exists(){
	grep "^${1}:" /etc/passwd 1>/dev/null && return 0
	return 1
}


convert_to_h(){
	res=$1
	if (($1 < 1024)); then 
		res=$( echo "$1" | awk '{  printf "%.2f KiB",$1}');
	elif (($1 >=1024)); then
		res=$( echo "$1" | awk '{ $1/=1024; printf "%.2f MiB",$1}');
	elif (($1 >=1048576)); then
		res=$( echo "$1" | awk '{ $1/=1024; printf "%.2f GiB",$1}');
	elif (($1 >=1073741824)); then
		res=$( echo "$1" | awk '{ $1/=1024; printf "%.2f TiB",$1}');
	elif (($1 >=1099511627776)); then
		res=$( echo "$1" | awk '{ $1/=1024; printf "%.2f PiB",$1}');
	fi
	echo $res
}

create_du_exe(){
	# Clean up code if exit prematurely
	#Write file
	tmp_du_exe=$(mktemp)
	echo '
	#!/bin/bash
	if [ -z "$1" ]; then echo ""
	else
		du "$1"
	fi' > $tmp_du_exe
	chmod +x $tmp_du_exe
}


remove_du_exe(){
	if [ -e "$tmp_du_exe" ]; then rm "$tmp_du_exe"; fi
}
	


# Process opts
while getopts ":u:d:ksh" opts; do
	case "${opts}" in 
		u)
			u=${OPTARG}
			if ! user_exists $u;
			then echo "user '$u' doesn't exist " >&2; exit 1
			fi
			;;
		d)
			d=${OPTARG}
			if ! [ -d "$d" ];
			then echo "'$d' Doesn't exist or it's not a dir" >&2; exit 1
			fi
			;;
		k)
			k=1
			;;
		s)
			s=1
			;;

		h)
			help 
			exit 0
			;;
		:)
			echo "-${OPTARG} requires an argument" >&2; exit 1
			;;
		*)
			help; exit 0
			;;




	esac
done

# set defaults
d=${d:=.}
u=${u:=$(whoami)}

# show starting message
if ! [[ $s == 1 ]]; then 
	echo "Searching files for user '$u' in dir '$(pwd)'. Please wait, this might take a wile ..."
fi



# create temp exe, otherwise very hard to process files with spaces and other
create_du_exe 
#clean on sudden exit
trap "rm \"$tmp_du_exe\" ; exit 1" SIGINT SIGTERM
# Do the work
totalkb=$(find "$d" -user "$u" -type f -print0 2>/dev/null |  xargs --null -n1 $tmp_du_exe | cut -f1 | awk 'BEGIN {totalkb=0} {totalkb+=$1} END {print totalkb}' )
# Remove temp file
remove_du_exe

# show analysis done msg
if ! [[ $s == 1 ]];then 
echo "DONE! Results below. Next time use '-s' option to get rid of these verbose messages"
fi

# Print human readable
if ! [[ $k == 1 ]]; then
	if ! [[ $s == 1 ]]; then echo "---------" ;fi
	echo  $(convert_to_h $totalkb)
	if ! [[ $s == 1 ]]; then echo "---------" ;fi
else 
	echo $totalkb 
fi
# exit succesfully
exit 0


