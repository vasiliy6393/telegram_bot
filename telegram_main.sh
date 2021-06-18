#!/bin/sh

. /etc/telegram_bot.vars;
. /etc/telegram_bot.conf;

PID_FILE="/tmp/telegram_bot.pid";
if [[ -e "$PID_FILE" ]]; then
    LAST_PID="$($CAT "$PID_FILE")";
    [[ "$LAST_PID" =~ ^[0-9]+$ ]] && $KILL -9 $LAST_PID;
fi
echo "$$" > "$PID_FILE";

function _help(){
    ADMIN="$1"; HELP="";
    HELP="$HELP/joke - случайный анекдот%0A";
    HELP="$HELP/weather - погода%0A";
    HELP="$HELP/translate_en_ru - переводчик с английского на русский%0A";
    HELP="$HELP/translate_ru_en - переводчик с русского на английский%0A";
    [[ "$ADMIN" == "true" ]] &&
        HELP="$HELP/exec cmd - выполнение произвольной команды (без root)%0A";
    [[ "$ADMIN" == "true" ]] && HELP="$HELP/new_emails - проверка новой почты%0A";
    [[ "$ADMIN" == "true" ]] &&
        HELP="$HELP/net_speed - узнать текущую скорость интернет%0A";
    HELP="$HELP/youtube_dl - Download from youtube%0A";
    HELP="$HELP/youtube_dl_list count=N page=N query%0A";
    HELP="$HELP/youtube_dl_cancel - cancel all downloads%0A";
    HELP="$HELP/help - показать эту справку";
    $TELEGRAM_BOT "$HELP" "$FROM_ID";
}

function _exec(){
    ADMIN="$1"; TEXT="$2"; FROM_ID="$3";
    if [[ "$ADMIN" == "true" ]]; then
        CMD=$(eval "$(echo "$TEXT" | sed 's/^\/exec //i')");
        $TELEGRAM_BOT "res: $CMD" "$FROM_ID";
    else
        $TELEGRAM_BOT "Permission denied" "$FROM_ID";
    fi
}

function net_speed(){
    ADMIN="$1"; FROM_ID="$2";
    [[ "$ADMIN" == "true" ]] && $TELEGRAM_BOT "$(/bin/net_speed.sh)" "$FROM_ID" ||
                                                     $TELEGRAM_BOT "Permission denied" "$FROM_ID";
}

function new_emails(){
    ADMIN="$1";
    FROM_ID="$2";
    if [[ "$ADMIN" == "true" ]]; then
        pass="_TOP_SECRET_";
        URL="https://mail.pogoreliy.tk/new_msg.php?html=true&tg=true&password=$pass&frid=$FROM_ID";
        $CURL "$URL" | $GREP -Po '\?id=[^&]+' | $AWK -F= '{print $2}' |
                       $SORT | $UNIQ | while read email_id; do
            n="$(($n+1))";
            $CURL -s "https://mail.pogoreliy.tk/$SECRET_PAGE?id=$email_id" > "/tmp/new_mail_$email_id.html";
            $TELEGRAM_BOT "New email:" "/tmp/new_mail_$email_id.html" "$FROM_ID";
            $RM "/tmp/new_mail_$email_id.html";
        done
    else
        $TELEGRAM_BOT "Permission denied" "$FROM_ID";
    fi
}

function translate(){
    TEXT="$1"; LANG="$2"; FROM_ID="$3";
    trans_res="$(echo "$TEXT" | $SED 's/^\/translate_.._.. //' | $TRANS "$LANG" -b)";
    $TELEGRAM_BOT "$trans_res" "$FROM_ID";
}

function weather(){
    FROM_ID="$1";
    $MKDIR -p "/tmp/weather_$FROM_ID";
    cd "/tmp/weather_$FROM_ID";
    WTH="weather.png";
    U1="https://weather.com/ru-RU/weather/tenday/l/";
    U2="bee83c0f4aa7de0d4905a612d06d3af59c";
    U3="c13086efe66a4db3537d88c2a46cca";
    URL="$U1$U2$U3";
    $CUTYCAPT --url="$URL" --out=$WTH;
    $TELEGRAM_BOT "Погода" "$WTH" "$FROM_ID";
    cd; $RM -R "/tmp/weather_$FROM_ID";
}

function youtube_dl_cancel(){
    FROM_ID="$1";
    PID_YOUTUBE_DL=$(ps aux | $GREP -P 'telegram_youtube_dl.sh' |
                              $GREP -P "$FROM_ID" | $AWK '{print $2}');
    [[ -n "$PID_YOUTUBE_DL" ]] && $KILL -9 $PID_YOUTUBE_DL;
    $RM -R "/tmp/youtube_dl_$FROM_ID";
}

function joke(){
    FROM_ID="$1";
    RES="$($CURL -s "http://rzhunemogu.ru/RandJSON.aspx?CType=1" |
           $ICONV -f windows-1251 -t utf-8 | $SED 's/{\"content\":\"\|\"}//g')";
    $TELEGRAM_BOT "$RES" "$FROM_ID";
}

function log(){
    TEXT="$1"; ID="$2"; FROM_ID="$3";
    echo "$FROM_ID: $TEXT" >> "$TELEGRAM_BOT_LOG_ADMIN";
    if [[ "$($STAT --printf="%s" "$TELEGRAM_BOT_LOG")" -ge "$LOG_SIZE_BYTE" ]]; then
        echo "$ID" > "$TELEGRAM_BOT_LOG";
    else
        echo "$ID" >> "$TELEGRAM_BOT_LOG";
    fi
}

while true; do
    URL="https://api.telegram.org/$TOKEN/getUpdates";
    RES="$($CURL -s -F offset=-1 $URL | $JQ ".result[] | .message.message_id,
                                           .message.from.id, .message.text")";
    ID="$(echo "$RES" | $HEAD -n1)";
    FROM_ID="$(echo "$RES" | $HEAD -n2 | $TAIL -n1)";
    [[ "$FROM_ID" == "_SECRET_" ]] && ADMIN="true" || ADMIN="false";
    TEXT="$(echo "$RES" | $TAIL -n1 | $SED 's/^\"\|\"$//g')";
    TEXT="$($PYTHON -c "print(u'$TEXT')")"; # TO CORRECTLY PARSE THE CYRILLIC

    if ! $GREP -Pq "$ID" "$TELEGRAM_BOT_LOG"; then
        if [[ -e "$BAN_LIST" ]] && $GREP -Pq "^$FROM_ID$" "$BAN_LIST"; then 
            $TELEGRAM_BOT "Permission denied" "$FROM_ID";
            log "$TEXT" "$ID" "$FROM_ID";
        else
            # начало регистро-независимого сравнения
            # start of register-independent string comparison
            shopt -s nocasematch;
            case "$TEXT" in
                /help*|/start*) _help "$ADMIN" "$FROM_ID";;
                /exec*)_exec "$ADMIN" "$TEXT" "$FROM_ID";;
                /net_speed*) net_speed "$ADMIN" "$FROM_ID";;
                /new_emails) new_emails "$ADMIN" "$FROM_ID";;
                /joke) joke "$FROM_ID";;
                /weather) weather "$FROM_ID";;
                /translate_en_ru*) translate "$TEXT" "en:ru" "$FROM_ID";;
                /translate_ru_en*) translate "$TEXT" "ru:en" "$FROM_ID";;
                /youtube_dl_cancel*) youtube_dl_cancel "$FROM_ID";;
                /youtube_dl_list*)
                    $TELEGRAM_YOUTUBE_DL "list" "$TEXT" "$FROM_ID" &;;
                /youtube_dl*)
                    URL="$(echo "$TEXT" | $SED 's/^\/youtube_dl *//g')";
                    $TELEGRAM_YOUTUBE_DL "$URL" "$FROM_ID" &;;
            esac
            # конец регистро-независимого сравнения
            # end of register-independent string comparison
            shopt -u nocasematch;
            # может не работать в некоторых системах
            # я выбрал вариант, который отнимает меньше системных ресурсов
            # если не работает, можно использовать связку ls и awk
            # или обратитесь к man странице своего дистрибутива
            # may not work on some systems
            # I chose the one that requires less system resources
            # if it does not work correctly, you can use ls and awk
            # or refer to the man page of your distribution
            log "$TEXT" "$ID" "$FROM_ID";
        fi
    fi
    sleep 1;
done
