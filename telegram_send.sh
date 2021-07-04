export SED="$(which sed)";
export CURL="$(which curl)";
export URLENCODE="$(which urlencode)";

UA="Mozilla/5.0 (X11; Linux i686; rv:83.0) Gecko/20100101 Firefox/83.0";
msg="$(echo "$1" | $SED 's/%0A/\n/g')";
. /etc/telegram_bot.conf;

[[ "$2" =~ ^[0-9]+$ ]] && CID="$2" || attach="$2";
[[ "$3" =~ ^[0-9]+$ ]] && CID="$3" || attachs=${@:3};

if [[ "a$attach" != "a" ]]; then
    URL="https://api.telegram.org/$TOKEN/sendDocument";
    msg="$(echo "$msg" | $URLENCODE)";
    $CURL -A "$UA" -d chat_id=$CID -d document=@"$attach" -d caption="$msg" "$URL"
    if [[ "a$attachs" != "a" ]]; then
        for i in $attachs; do
            $CURL -s -A "$UA" -F chat_id="$CID" -F document=@"$i" "$URL";
        done
    fi
else
    URL="https://api.telegram.org/$TOKEN/sendMessage";
    msg="$(echo "$msg" | $URLENCODE)";
    $CURL -s -A "$UA" -d parse_mode="html" -d chat_id="$CID" -d text="$msg" "$URL";
fi
