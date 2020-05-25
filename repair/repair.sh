#! /bin/bash
ROOT=`pwd`
DIR="$ROOT/example"
FILES="filenames.txt"
FIXD="fixnames.txt"
LOG="$DIR/log.txt"
OLD=""
NEW=""
COUNT=0
ARR_NDIR=""
ARR_NFILE=""
ARR_FDIR=""
ADDSTR=""
SPLIT=""
OLD_IFS=$IFS
TM=`date +%s`
source $DIR/config.sh

if [ -d $DIR/code ]; then
	if [ -d $DIR/code_down ]; then
		rm -rf $DIR/code_down
	fi
	`cp -rf $DIR/code $DIR/code_down`	
	[ $? -eq 0 ] && DIR=$DIR/code_down || exit
else 
	echo "no dir code!"  
	exit -2
fi

check_config()
{
	IFS=":"
	local arr=($1)
	IFS=$OLD_IFS
	for ((i=0; i<${#arr[@]}; i++))
	do
		local flag="$DIR/${arr[i]}"
		[ ! -d "$flag" -a ! -f "$flag" ] && echo "TIP: config $flag is noexist!" && continue
		arr[i]=$flag
	done
	case $2 in
		1)
			ARR_NDIR=(${arr[@]})
			;;
		2)
			ARR_NFILE=(${arr[@]})
			;;
		3)	
			ARR_FDIR=(${arr[@]})
			;;
	esac
}

config()
{
	local flag=`echo $SITE | sed 's/[0-9]//g'`
	if [ -z "$flag" -a ! -z "$SITE" ]; then
		[ $SITE -ne 1 -a $SITE -ne 2 ] && SITE=1
	else
		SITE=1
	fi
	flag=`echo $SIZE | sed 's/[0-9]//g'`
	if [ -z "$flag" -a ! -z "$SIZE" ]; then
		[ $SIZE -lt 1 -o $SIZE -gt 10 ] && SIZE=5
	else
		SIZE=5
	fi
	flag=`echo $STRING | sed 's/[0-9]//g'`
	if [ -z "$flag" -a ! -z "$STRING" ]; then
		[ $STRING -ne 1 -a $STRING -ne 2  -a $STRING -ne 3 -a $STRING -ne 4 ] && STRING=3	
	else
		STRING=3
	fi
	
	flag=`echo $NO_REPLACE_DIR | sed 's/ //g'`
	[ ! -z "$NO_REPLACE_DIR" -a ! -z "$flag" ] && check_config "$NO_REPLACE_DIR" 1	|| echo "NO_REPLACE_DIR is null"

	flag=`echo $NO_REPLACE_FILE | sed 's/ //g'`
	[ ! -z "$NO_REPLACE_FILE" -a ! -z "$flag" ] && check_config "$NO_REPLACE_FILE" 2 || echo "NO_REPLACE_FILE is null"

	flag=`echo $FIX_REPLACE_DIR | sed 's/ //g'`
	[ ! -z "$FIX_REPLACE_DIR" -a ! -z "$flag" ] && check_config "$FIX_REPLACE_DIR" 3 || echo "FIX_REPLACE_DIR is null"
}
config

:>$LOG;:>$FILES;:>$FIXD;:>tr_str;:>tr_str2
find_files()
{
	for f in $1/*
	do
		if [ -d "$f" ]; then
			find_files "$f" $2 $3 $4
		else
			suffix=${f##*.}
			case "$suffix" in 
				"png" | "jpg" | "jpeg" | "json" | "mp3" | "lua")
					case "$3" in
						"add")
							echo $f >>$2
							;;
						"rm")
							sed -i "s#$f#$SPLIT#g" $2
							;;
						"mv")
							sed -i "s#$f#$SPLIT#g" $2
							echo $f >> $4	
							;;
					esac
					;;
			esac
		fi
	done
}

find_replace()
{		
	echo "DIR=$DIR"
	find_files "$DIR" "$FILES" "add"
	for d in ${ARR_NDIR[@]}
	do
		find_files "$d" "$FILES" "rm"
	done

	for f in ${ARR_NFILE[@]}	
	do
		sed -i "s#$f#$SPLIT#g" $FILES
	done

	for d in ${ARR_FDIR[@]}
	do
		echo "d=$d"
		find_files "$d" "$FILES" "mv" "$FIXD"
	done
}
find_replace

tr_str()
{
	:>tr_str;:>tr_str2
	local old=${OLD##*/}
	local new=${NEW##*/}
	local suffix=${old##*.}
	case "$suffix" in
		"lua" )
			old="${old%.*}"
			new="${new%.*}"
			egrep "\"$old\"|/$old\"|\.$old\"" $1 -rl | sed "s#$OLD#$SPLIT#g" | grep "\.lua$" >> tr_str2
			:<<!
			grep "\"$old\"" $1 -rl >> tr_str
			sed -i "s#$OLD#$SPLIT#g" tr_str		#lua文件不能引用自己
			grep "/$old\"" $1 -rl >> tr_str
			grep "\.$old\"" $1 -rl >> tr_str
			grep "\.lua$" tr_str | sort -u  >> tr_str2	
!
			;;
		"png" | "jpg" | "jpeg" | "mp3")
			egrep "\"$old\"|/$old\"" $1 -rl |  egrep "\.lua$|\.json$" >> tr_str2
			:<<!
			grep "\"$old\"" $1 -rl >> tr_str
			grep "/$old\"" $1 -rl >> tr_str
			grep "\.lua$" tr_str >> tr_str2
			grep "\.json$" tr_str | sort -u >> tr_str2
!
			;;
		"json")
			egrep "\"$old\"|/$old\"" $1 -rl | grep "\.lua$" >> tr_str2
			:<<!
			grep "\"$old\"" $1 -rl >> tr_str
			grep "/$old\"" $1 -rl >> tr_str
			grep "\.lua$" tr_str | sort -u >> tr_str2
!
			;;
	esac	
	#只通过文件名查找存在找到被引用的是同名文件的可能, 先缩小查找范围
	
	COUNT=`cat tr_str2 | wc -l`
	if [ $COUNT -gt 0 ]; then
		echo "COUNT=$COUNT"
		#1 全局唯一， 直接引用, lua文件带路径，有的路径用字符拼接   abc .. "test"
		sed -i "s#\"$old\"#\"$new\"#g" `cat tr_str2`		

		echo "多级目录"
		#2 依次引用一级引用路径，二级路径， 直到遇到code_down目录为止
		IFS="/"
		local arr=($OLD)
		IFS=$OLD_IFS
		local len=${#arr[@]}
		local _path=""
		local _old=$old
		local _new=$new
		for ((i=$((len - 2)); i>=0; i--)) 
		do
			_path=${arr[i]}
			[ "$_path" = "code_down" ] && break
			_old="$_path/$_old"
			_new="$_path/$_new"
			echo "_old=$_old"
			sed -i "s#\"$_old\"#\"$_new\"#g" `cat tr_str2`		
		done
	
		# 引用lua时的特殊情况	
		if [ "$suffix" = "lua" ]; then
			echo "lua特殊情况"
			_old=$old
			_new=$new
			for ((i=$((len - 2)); i>=0; i--)) 
			do
				_path=${arr[i]}
				[ "$_path" = "code_down" ] && break
				_old="$_path.$_old"
				_new="$_path.$_new"
				echo "_old=$_old"
				sed -i "s#\"$_old\"#\"$_new\"#g" `cat tr_str2`		
			done
		fi
	fi
}

add_str()
{
	local str=""
	ADDSTR=""
	case $STRING in
		1)
			str="1234567890"	
		;;
		2)
			str="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
		;;
		3)
			str="123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
		;;
	esac
	local num=${#str}
	for ((i=1;i<=$SIZE;i++))
	do
		local n=`expr $RANDOM % $num`
		local a=${str:n:1}
		ADDSTR=$ADDSTR$a
	done
}

replace_normal()
{
	echo "replace_normal" >> $LOG
	cat $FILES | while read line 
	do
		[ "$line" = "$SPLIT" ] && continue 
		OLD=${line##*/}
		local suffix=${OLD##*.}
		local fpath=${line%/*}
		local name=""
		if [ $STRING -ne 4 ]; then
			add_str
			name=${OLD%.*}
			[ $SITE -eq 1 ]	&& NEW="$ADDSTR$name.$suffix"  || NEW="$name$ADDSTR.$suffix"
		else
			echo "$line" > encrypt
			name=(`md5sum encrypt`)	#取数组第一个值
			NEW="$name.$suffix"
		fi
		OLD=$line
		NEW="$fpath/$NEW"
		local info="$OLD >> $NEW"
		echo $info && echo $info >> $LOG
		tr_str	"$DIR" 

		mv "$OLD" "$NEW"	
		info="查找替换文件数量: $COUNT"
		echo -e $info && echo -e $info >> $LOG
	done
}

replace_fix()
{
	[ $STRING -eq 4 ] && STRING=3
	add_str
	ADDSTR=""  #test
	echo "replace_fix STRING=$STRING  add_str=$ADDSTR"	>>$LOG
	cat $FIXD | while read line
	do
		[ "$line" = "$SPLIT" ] && continue
		OLD=${line##*/}
		local fpath=${line%/*}
		local suffix=${OLD##*.}
		local name=${OLD%.*}
		[ $SITE -eq 1 ]	&& NEW="$ADDSTR$name.$suffix"  || NEW="$name$ADDSTR.$suffix"

		OLD=$line NEW="$fpath/$NEW"
		local info="$OLD >> $NEW"
		echo $info && echo $info >> $LOG
		tr_str "$DIR"

		mv "$OLD" "$NEW"	
		info="查找替换文件数量: $COUNT"
		echo -e $info && echo -e $info >> $LOG
	done
}

match()
{
	echo -e "\n\n\nlua文件中模式串:" >>$LOG
	egrep "%s.*.png|%s.*.jpg|%s.*.mp3|%d.*.png|%d.*.jpg|%d.*.mp3" $DIR -rn >> $LOG
}

replace_normal
replace_fix
match
NOW=`date +%s`
TM=`expr $NOW - $TM`
TIP="\n\n\nspend $TM second." 
echo -e $TIP && echo -e $TIP >> $LOG
rm tr_str tr_str2
[ $STRING -eq 4 ] && rm encrypt


#思路:查找到所有替换文件， 减去指定不需替换的文件, 减去固定替换文件
#重点(前提和被处理代码文件格式有关): 同名文件的处理， 同名文件引用一定有路径， 用路径确定被引用的文件, 在前提条件下才成立

