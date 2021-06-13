#!/bin/sh

[[ "$2" =~ ^[0-9]+$ ]] && CID="$2"; [[ "$3" =~ ^[0-9]+$ ]] && CID="$3";

TMP_PATH="/tmp/youtube_dl_$CID";

if [[ "$1" == "list" ]]; then
    TEXT="$2";
    if echo "$TEXT" | $GREP -Pq 'count=[0-9]+'; then
        COUNT="$(echo "$TEXT" | $SED 's/.*count=\([0-9]\+\).*/\1/i')";
    else
        COUNT="5";
    fi
    if echo "$TEXT" | $GREP -Pq 'page=[0-9]+'; then
        PAGE="&$(echo "$TEXT" | $SED 's/.*\(page=[0-9]\+\).*/\1/i')";
    else PAGE=""; fi
    Q="$(echo "$TEXT" | $SED 's/page=[0-9]\+//gi' |
                        $SED 's/count=[0-9]\+//gi' |
                        $SED 's/\/youtube_dl_list \(.*\)/\1/')";
    $YOUTUBEDL "ytsearch$COUNT:$Q$PAGE" --skip-download --get-id --get-duration |
    $SED ':a;N;$!ba;s/\([^:]\+\)\n/\1 /g' |
    while read line; do
        id="$(echo "$line" | awk '{print $1}')";
        dur="$(echo "$line" | awk '{print $2}')";
        URL="/youtube_dl     https://www.youtube.com/watch?v=$id";
        $TELEGRAM_SEND "$URL%0A($dur)" "$CID";
    done
else
    URL="$(echo "$1" | $SED 's/^\/youtube_dl //')";
    YOUTUBE_DL_PARAMS="bestvideo[height<=480]+bestaudio/best[height<=480]";
    $MKDIR -p "$TMP_PATH";
    cd "$TMP_PATH";
    $TELEGRAM_SEND "youtube_dl: download" "$CID";
    RES_YOUTUBE_DL="$($YOUTUBEDL -f "$YOUTUBE_DL_PARAMS" "$URL" 2>&1)";
    
    $LS -1 | while read file; do
        $MV "$file" "$(echo "$file" |
        $SED 's/[^a-zA-Z0-9а-яА-ЯёЁ\ \.\-_\!,%#\&\*@№<>{}()\`\~\\\/\$\^?]\+/_/g')";
    done
    
    FILE="$($LS -1 | $HEAD -n1)";
    FILENAME="$(echo "$FILE" | $SED 's/\(.*\)\.[a-zA-Z0-9]\+$/\1/')";
    FILE_EXP="$(echo "$FILE" | $SED 's/.*\.\([a-zA-Z0-9]\+\)$/\1/')";
    FILE_SIZE="$($LS -l "$FILENAME.$FILE_EXP" | awk '{print $5}')";
    
    if [[ "$FILE_SIZE" -ge "50331648" ]]; then # if attach size >= 48 Mbyte
        INPUT="$FILENAME.$FILE_EXP";
        NEW_NAME="$(echo "$FILENAME" | sed 's/[\,]//g' | grep -Po '^.{0,25}')";
        OUTPUT="$NEW_NAME.rar";
        RES_SPLIT="$($RAR a -v45000k "$OUTPUT" "$INPUT" 2>&1 &&
                     $RM "$FILENAME.$FILE_EXP")";
        if echo "$RES_SPLIT" | $GREP -Pq '^Done$'; then
            FILES_LIST="$($LS -1)";
            FILES_COUNT="$(echo "$FILES_LIST" | $WC -l)"
            $TELEGRAM_SEND "youtube_dl: $FILES_COUNT file(s)" "$CID";
            echo "$FILES_LIST" | while read file; do
                $TELEGRAM_SEND "youtube_dl: $NEW_NAME" "$file" "$CID"; $RM "$file";
            done
        else
            ERROR="$(echo -en "$RES_YOUTUBE_DL\n$RES_SPLIT\n" |
                          $SED ':a;N;$!ba;s/\([^:]\+\)\n/\1%0A/g')";
            $TELEGRAM_SEND "youtube_dl_error: $ERROR" "$CID";
        fi
        $TELEGRAM_SEND "youtube_dl: done" "$CID";
    else # if attach size < 48 Mbyte
        # send as is
        $TELEGRAM_SEND "youtube_dl: $NEW_NAME" "$FILENAME.$FILE_EXP" "$CID";
    fi
    $RM -R "$TMP_PATH"; # clear
fi
