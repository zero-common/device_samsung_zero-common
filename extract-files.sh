#!/bin/bash
#
# Copyright (C) 2013, 2014 The CyanogenMod Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Extract DEX file from inside Android Runtime OAT file using radare2
# Copyright (C) 2013 Pau Oliva (@pof)
#
# https://github.com/poliva/random-scripts/blob/master/android/oat2dex.sh
#

set -e

if [ $# -eq 0 ]; then
  SRC=adb
else
  if [ $# -eq 1 ]; then
    SRC=$1
  else
    echo "$0: bad number of arguments"
    echo ""
    echo "usage: $0 [PATH_TO_EXPANDED_ROM]"
    echo ""
    echo "If PATH_TO_EXPANDED_ROM is not specified, blobs will be extracted from"
    echo "the device using adb pull."
    exit 1
  fi
fi


oat2dex()
{
    APK="$1"

    OAT="`dirname $APK`/arm/`basename $APK .apk`.odex"
    if [ ! -e $OAT ]; then
        return 0
    fi

    HIT=`r2 -q -c '/ dex\n035' "$OAT" 2>/dev/null | grep hit0_0 | awk '{print $1}'`
    if [ -z "$HIT" ]; then
        echo "ERROR: Can't find dex header of `basename $APK`"
        return 1
    fi

    SIZE=`r2 -e scr.color=false -q -c "px 4 @$HIT+32" $OAT 2>/dev/null | tail -n 1 | awk '{print $2 $3}' | sed -e "s/^/0x/" | rax2 -e`
    r2 -q -c "pr $SIZE @$HIT > /tmp/classes.dex" "$OAT" 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "ERROR: Something went wrong in `basename $APK`"
    fi
}

extract()
{
    for FILE in `egrep -v '(^#|^$)' $1`; do
    OLDIFS=$IFS IFS=":" PARSING_ARRAY=($FILE) IFS=$OLDIFS
    FILE=${PARSING_ARRAY[0]}
    DEST=${PARSING_ARRAY[1]}
    if [ -z $DEST ]
    then
        DEST=$FILE
    fi
    DIR=`dirname $FILE`
    if [ ! -d $2/$DIR ]; then
        mkdir -p $2/$DIR
    fi

    if [ "$SRC" = "adb" ]; then
        adb pull /system/$FILE $2/$DEST
        # if file does not exist try destination
        if [ "$?" != "0" ]
        then
            adb pull /system/$DEST $2/$DEST
        fi
        if [ "${FILE##*.}" = "apk" ]; then
            oat2dex /system/$FILE
        fi
    else
        cp $SRC/$FILE $2/$FILE
        if [ "${FILE##*.}" = "apk" ]; then
            oat2dex $SRC/$FILE
        fi
    fi

    if [ -e /tmp/classes.dex ]; then
        zip -gjq $2/$FILE /tmp/classes.dex
        rm /tmp/classes.dex
    fi

done
}

BASE=../../../vendor/$VENDOR/zero-common/proprietary
rm -rf $BASE/*

DEVBASE=../../../vendor/$VENDOR/$DEVICE/proprietary
rm -rf $DEVBASE/*

extract ../../$VENDOR/zero-common/common-proprietary-blobs.txt $BASE
extract ../../$VENDOR/$DEVICE/device-proprietary-blobs.txt $DEVBASE

./../zero-common/setup-makefiles.sh
