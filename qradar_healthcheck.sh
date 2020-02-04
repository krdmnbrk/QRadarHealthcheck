#!/bin/bash
#Author: Burak Karaduman <burakkaradumann@gmail.com>

clear

red="\e[91m"
green="\e[92m"
reset="\e[0m"
yellow="\e[93m"
bold="\e[1m"

D="--------------------------------------------------------------------"

if [ $(/opt/qradar/bin/myver -c) == "true" ]
then
    NVACONF=$(cat /opt/qradar/conf/nva.conf)
    CONSOLEIP=$(echo -e "$NVACONF" | grep -o -P '(?<=CONSOLE_PRIVATE_IP=).*')
    LASTVERSION=$(echo "$NVACONF" | grep -o -P -i '(?<=Internal build version: ).*?(?=.<br)')
    OS=$(cat /etc/system-release)

    LSCPU=$(lscpu)
    ARCH=$(echo "$LSCPU" | grep -i 'architecture:' | awk -F ':' '{print $2}' | sed 's/\s*//')
    CORE=$(echo "$LSCPU" | grep -i '^cpu(s):' | awk -F ':' '{print $2}' | sed 's/\s*//')
    MODEL=$(echo "$LSCPU" | grep -i 'model name:' | awk -F ':' '{print $2}' | sed 's/\s*//')

    TOTALMEM=$(free -th | grep -i '^Total' | awk '{print $2'})
    

    echo -e $bold
    echo $D
    echo "-*- QRadar Healthcheck -*-"
    echo ""
    echo "Version      : $LASTVERSION"
    echo "OS           : $OS"
    echo "Architecture : $ARCH"
    echo "Processor    : $MODEL"
    echo "CPU(s)       : $CORE"
    echo "Total Memory : $TOTALMEM"
    echo $D
    echo -e $reset
    
    # Memory Usage
    SSHFAILURE=""
    CRITICAL="HOSTNAME,CURRENT_MEMORY_USAGE"
    CRITICALVALUE=80
    HASCRITIAL="no"

    while IFS= read -r line
    do 
            HOSTNAME=$(echo $line | awk -F ' | ' '{print $1}')
            IP=$(echo $line | awk -F ' | ' '{print $2}')
            if [[ $(echo $HOSTNAME) == *"$(hostname)"* || "$(hostname)" == *$(echo $HOSTNAME)* ]]
            then
                MEMORY_USAGE=$(free -t | awk 'NR == 2 {print int(\$3/\$2*100)}')
            else
                MEMORY_USAGE=$(ssh -nq -o ConnectTimeout=10 $HOSTNAME "free -t | awk 'NR == 2 {print int(\$3/\$2*100)}'")
                if [ `echo $?` -eq "255" ]
                then
                    SSHFAILURE+="$HOSTNAME,"
                    continue
                fi
            fi
            
            if [ $MEMORY_USAGE -gt $CRITICALVALUE ]
            then
                    CRITICAL+="\n$HOSTNAME,%$MEMORY_USAGE"
                    HASCRITIAL="yes"
            else
                    NORMAL+="\n$HOSTNAME,%$MEMORY_USAGE"
            fi
            
    done < <(psql -U qradar -t -c "select hostname, ip from managedhost where status='Active'" | grep -v $(/opt/qradar/bin/myver -cip) | head -n -1)

    if [ $HASCRITIAL == "yes" ]
    then
        echo -e "$red[-] Some hosts are using memory more than %$CRITICALVALUE$reset"
        echo -e $CRITICAL | column -t -s "," | sed 's/^/    /'
    else
        echo -e "$green[+] Memory usage is under %$CRITICALVALUE"
    fi
    if [ "$SSHFAILURE" != "" ]
    then
        echo -e "\t${red}*** Cannot connect to '$(echo -e $SSHFAILURE | sed 's/,$//')' on SSH ***"
    fi
    ####################################################################################################################################
    
    
    
    # CPU Usage
    SSHFAILURE=""
    CRITICALVALUE=80
    CRITICAL="HOSTNAME,%CPU(Last 1 minutes),%CPU(Last 5 minutes),%CPU(Last 15 minutes)"
    HASCRITIAL="no"
    MANAGEDHOSTCOUNT=$(psql -t -U qradar -c "select * from managedhost where status = 'Active'" | head -n -1 | wc -l)
    while IFS= read -r line
    do
            HOSTNAME=$(echo $line | awk -F ' | ' '{print $1}')
            IP=$(echo $line | awk -F ' | ' '{print $2}')
            if [[ $(echo $HOSTNAME) == *"$(hostname)"* || "$(hostname)" == *$(echo $HOSTNAME)* ]]
            then
                uptime=$(uptime)
            else
                uptime=$(ssh -nq -o ConnectTimeout=10 $HOSTNAME 'uptime')
                if [ `echo $?` -eq "255" ]
                then
                    SSHFAILURE+="$HOSTNAME,"
                    continue
                fi
            fi
            
            onemin=$(echo $uptime | awk '{print $10$11$12}' | awk -F ',' '{print int($1)}')
            fivemin=$(echo $uptime | awk '{print $10$11$12}' | awk -F ',' '{print int($2)}')
            fifteenmin=$(echo $uptime awk '{print $10$11$12}' | awk -F ',' '{print int($3)}')
            CPU_USAGE="${onemin},${fivemin},${fifteenmin}"
            if [ ${onemin} -gt $CRITICALVALUE ] || [ ${fivemin} -gt $CRITICALVALUE ] || [ ${fifteenmin} -gt $CRITICALVALUE ]
            then
                    CRITICAL+="\n$HOSTNAME,%$CPU_USAGE"
                    HASCRITIAL="yes"
            else
                    NORMAL+="\n$HOSTNAME,%$CPU_USAGE"
            fi

    done < <(psql -U qradar -t -c "select hostname, ip from managedhost where status='Active'" | grep -v $(/opt/qradar/bin/myver -cip) | head -n -1)

    if [ $HASCRITIAL == "yes" ]
    then
        echo -e "$red[-] Some hosts are using CPU more than %$CRITICALVALUE$reset"
        echo -e $CRITICAL | column -t -s "," | sed 's/^/    /'
    else
        echo -e "$green[+] CPU usage is under %$CRITICALVALUE"
    fi
    if [ "$SSHFAILURE" != "" ]
    then
        echo -e "\t${red}*** Cannot connect to '$(echo -e $SSHFAILURE | sed 's/,$//')' on SSH ***"
    fi
    ####################################################################################################################################



    # Disk Usage
    SSHFAILURE=""
    CRITICALVALUE=90
    CRITICAL="HOSTNAME,IP,MOUNTED_ON,PERCENTAGE,AVAIL,USED,TOTAL"
    while IFS= read -r line
    do
        HOSTNAME=$(echo -e $line | awk -F '|' '{print $1}')
        IP=$(echo -e $line | awk -F '|' '{print $2}' | sed 's/ //')
        if [[ $(echo $HOSTNAME) == *"$(hostname)"* || "$(hostname)" == *$(echo $HOSTNAME)* ]]
        then
            DU=$(df -h | sed 1d)
        else
            DU=$(ssh -nq -o ConnectTimeout=10 $HOSTNAME 'df -h | sed 1d')
            if [ `echo $?` -eq "255" ]
            then
                SSHFAILURE+="$HOSTNAME,"
                continue
            fi
        fi
        while IFS='%' read -r host
        do
            FOLDER=$(echo -e $host | awk '{print $6}')
            USAGE=$(echo -e $host | awk '{print $5}' | awk -F '%' '{print $1}')
            TOTAL=$(echo -e $host | awk '{print $2}')
            USED=$(echo -e $host | awk '{print $3}')
            AVAIL=$(echo -e $host | awk '{print $4}')

            if [ $USAGE -gt $CRITICALVALUE ]
            then
                CRITICAL+="\n$HOSTNAME,$IP,$FOLDER,%$USAGE,$AVAIL,$USED,$TOTAL"
            fi
        done <<< "$DU"
    done < <(psql -t -U qradar -c "select hostname, ip from managedhost where status = 'Active'" | head -n -1)
    if [ $(echo -e $CRITICAL | wc -l ) -ne 1 ]
    then
        echo -e "$red[-] Some disks are over %90$reset"
        echo -e $CRITICAL | column -t -s ',' | sed 's/^/    /'
    else
        echo -e "$green[+] Disk usage is normal$reset"
    fi
    if [ "$SSHFAILURE" != "" ]
    then
        echo -e "\t${red}*** Cannot connect to '$(echo -e $SSHFAILURE | sed 's/,$//')' on SSH ***"
    fi
    ####################################################################################################################################



    # Is the Tomcat is running? 0 okey, 1 not
    tomcatresult=$(systemctl status tomcat | grep -q 'Active: active'; echo $?)
    if [ $tomcatresult == "0" ]
    then
        echo -e "$green[+] Tomcat is up$reset"
    else
        echo -e "$red[-] Tomcat is down$reset"
    fi
    ####################################################################################################################################


   
    # Is the QRadar Console UI accessible?
    uiresult=$(curl -Iks https://$CONSOLEIP | head -1 | grep -q 200 >/dev/null 2>&1; echo $?)
    if [ $uiresult == "0" ]
    then
        echo -e "$green[+] User interface is up$reset"
    else
        echo -e "$red[-] User interface is down$reset"
    fi
    ####################################################################################################################################


     # Services
    SSHFAILURE=""
    ALLSERVICESTATUS="HOSTNAME,SERVICE,STATUS\n"
    while IFS= read -r line
    do
        HOSTNAME=$(echo -e $line | awk -F '|' '{print $1}')
        IP=$(echo -e $line | awk -F '|' '{print $2}' | sed 's/ //')
        if [[ $(echo $HOSTNAME) == *"$(hostname)"* || "$(hostname)" == *$(echo $HOSTNAME)* ]]
        then
            EXACTSERVICES="tomcat,hostservices,hostcontext"
            ALLSERVICES=$(for i in $(echo -e $(grep COMPONENT /opt/qradar/conf/nva.hostcontext.conf | awk -F '=' '{print $2}'),$EXACTSERVICES | tr "," "\n"); do if [ $(echo "$i" | grep -v tunnel) ]; then echo "$(echo $i | awk -F '.' '{print $1}'):$(systemctl status $(echo $i | awk -F '.' '{print $1}') | grep 'Active: ' | awk '{print $2}')"; fi; done)
        else
            EXACTSERVICES="hostservices,hostcontext"
            ALLSERVICES=$(ssh -nq $HOSTNAME "for i in \$(echo -e \"\$(grep COMPONENT /opt/qradar/conf/nva.hostcontext.conf | awk -F '=' '{print \$2}'),$EXACTSERVICES\" | tr \",\" \"\n\"); do if [ \$(echo \"\$i\" | grep -v tunnel) ]; then echo \"\$(echo \$i | awk -F '.' '{print \$1}'):\$(systemctl status \$(echo \$i | awk -F '.' '{print \$1}') | grep 'Active: ' | awk '{print \$2}')\"; fi; done")
            if [ "$?" == "255" ]
            then
                SSHFAILURE+="$HOSTNAME,"
                continue
            fi
        for service in $ALLSERVICES
        do
            SERVICENAME=$(echo "$service" | awk -F ':' '{print $1}')
            SERVICESTATUS=$(echo "$service" | awk -F ':' '{print $2}')
            if [ "$SERVICESTATUS"  != "active" ]
            then
                ALLSERVICESTATUS+="$HOSTNAME,$SERVICENAME,$SERVICESTATUS\n"
            fi
        done
        fi      
    done < <(psql -t -U qradar -c "select hostname, ip from managedhost where status = 'Active'" | head -n -1)

    if [ "$SSHFAILURE" != "" ]
    then
        echo -e "\t${red}*** Cannot connect to '$(echo -e $SSHFAILURE | sed 's/,$//')' on SSH ***"
    fi

    if [ "$ALLSERVICESTATUS" == "HOSTNAME,SERVICE,STATUS\n" ]
    then
        echo -e "$green[+] All services are working$reset"
    else
        echo -e "$red[-] Some services are not working$reset"
        echo -e "$ALLSERVICESTATUS" | column -t -s ',' | sed 's/^/    /'
    fi




    # System Notifications
    NOTIFICATIONS=$(psql -U qradar -c "select managedhost.hostname, qidmap.qname, count(qidmap.qname) from notification inner join qidmap on qidmap.qid=notification.qid inner join managedhost on managedhost.ip=notification.hostip where qidmap.severity > 3 and notification.creationdate > NOW() - interval '24 hours' group by managedhost.hostname,qidmap.qname order by count(qidmap.qname) DESC" | sed 's/^/    /')

    if [ $(echo -e $NOTIFICATIONS | grep -i '(0 rows)' >/dev/null 2>&1; echo $?) -eq 0 ]
    then
        echo -e "$green[+] There are no system notifications last 24 hours$reset"
    else
        echo -e "$red[-] There are system notifications last 24 hours$reset"
        echo -e "$NOTIFICATIONS"
    fi
    ####################################################################################################################################



    
    
    # Are all Managed Hosts showing the expected Status?
    managedhostresult=$(psql -t -U qradar -c "select hostname, ip, status from managedhost where status != 'Deleted'" | head -n -1 | grep -vi Active >/dev/null 2>&1; echo $?)
    managedhostINFO=$(psql -U qradar -c "select hostname, ip, status from managedhost where status != 'Deleted'" | sed 's/^/    /')
    if [ $managedhostresult == "1" ]
    then
        echo -e "$green[+] All managed hosts are active$reset"
    else
        echo -e "$red[-] Some managed hosts are not active$reset\n$managedhostINFO"
    fi
    ####################################################################################################################################




   
    # Are all apps running?
    appsresult=$(psql -t -U qradar -c "select id, name, status from installed_application" | head -n -1 | grep -vi RUNNING >/dev/null 2>&1; echo $?)
    appINFO=$(psql -U qradar -c "select id, name, status from installed_application where status != 'RUNNING'" | sed 's/^/    /')
    appCount=$(psql -tU qradar -c "select count(id) from installed_application" | head -n -1)
    if [ $appsresult == "1" ]
    then
        echo -e "$green[+] All apps are running$reset"
    
    elif [ $appCount == "0" ]
    then
        echo -e "$green[+] There is no installed app$reset"
    else
        echo -e "$red[-] Some apps are not running$reset\n$appINFO"
    fi
    ####################################################################################################################################


    # # Has Deploy Changes
    # HASDEPLOY=$(/opt/qradar/upgrade/bin/undeployed_check.pl | grep 'There are no un-deployed changes'; echo $?)
    # if [ $HASDEPLOY == "0" ]
    # then
    #     echo -e "$green[+] There are no un-deployed changes$reset"
    # else
    #     echo -e "$yellow[~] Please go to the Administration Console and deploy changes before continuing with the upgrade$reset"
    # fi
    # ####################################################################################################################################
    
    
    # Persistent Queue
    SSHFAILURE=""
    CRITICALVALUE=10
    HASFILE="HOSTNAME,PATH,FILE_COUNT\n"
    while IFS= read -r line
    do
        HOSTNAME=$(echo -e $line | awk -F '|' '{print $1}')
        IP=$(echo -e $line | awk -F '|' '{print $2}' | sed 's/ //')
        if [[ $(echo $HOSTNAME) == *"$(hostname)"* || "$(hostname)" == *$(echo $HOSTNAME)* ]]
        then
            if [ -d /store/persistent_queue ]
            then
                DIRS=$(for i in $(ls /store/persistent_queue/); do     echo "$i=$(ls /store/persistent_queue/$i | wc -l)"; done;)
            else
                continue
            fi
        else
            DIRS=$(ssh -nq -o ConnectTimeout=10 $HOSTNAME 'if [ -d  /store/persistent_queue ];then for i in $(ls /store/persistent_queue/); do     echo "$i=$(ls /store/persistent_queue/$i | wc -l)"; done; fi')
            if [ "$?" == "255" ]
            then
                SSHFAILURE+="$HOSTNAME,"
                continue
            elif [ "$DIRS" == "" ]
            then
                continue
            fi
        fi
        while IFS= read -r dir
        do  
            COUNT=$(echo "$dir" | awk -F '=' '{print $2}')
            PTH="/store/persistent_queue/$(echo "$dir" | awk -F '=' '{print $1}')"
            if [ $COUNT -gt $CRITICALVALUE ]
            then
                HASFILE+="$HOSTNAME,$PTH,$COUNT\n"
            fi
        done <<< "$DIRS"

    done < <(psql -t -U qradar -c "select hostname, ip from managedhost where status = 'Active'" | head -n -1)

    if [ "$HASFILE" != "HOSTNAME,PATH,FILE_COUNT\n" ]
    then
        echo -e "$red[-] There are some persistent queues$reset"
        echo -e "$HASFILE" | column -t -s ',' | sed 's/^/    /'
    else
        echo -e "$green[+] No persistent queue$reset"
    fi
    if [ "$SSHFAILURE" != "" ]
    then
        echo -e "\t${red}*** Cannot connect to '$(echo -e $SSHFAILURE | sed 's/,$//')' on SSH ***"
    fi
    # Spillover
    SSHFAILURE=""
    CRITICALVALUE=10
    SPILLOVERRESULT="HOSTNAME,SPILLOVER\n"
    while IFS= read -r line
    do
        HOSTNAME=$(echo -e $line | awk -F '|' '{print $1}')
        IP=$(echo -e $line | awk -F '|' '{print $2}' | sed 's/ //')
        if [[ $(echo $HOSTNAME) == *"$(hostname)"* || "$(hostname)" == *$(echo $HOSTNAME)* ]]
        then
            SPILLOVERCOUNT=$(cat /var/log/qradar.log | grep QueuedEventThrottleFilter | grep -P -o 'Current events spillover: \d+' | tail -1 | awk -F ': ' '{print $2}')
        else
            SPILLOVERCOUNT=$(ssh -nq -o ConnectTimeout=10 $HOSTNAME "cat /var/log/qradar.log | grep QueuedEventThrottleFilter | grep -P -o 'Current events spillover: \d+' | tail -1 | awk -F ': ' '{print \$2}'")
            if [ "$?" == "255" ]
            then
                SSHFAILURE+="$HOSTNAME,"
                continue
            elif [ "$SPILLOVERCOUNT" == "" ]
            then
                continue
            elif [ $SPILLOVERCOUNT -gt $CRITICALVALUE ]
            then
                SPILLOVERRESULT+="$HOSTNAME,$SPILLOVERCOUNT\n"
            fi
        fi
    done < <(psql -t -U qradar -c "select hostname, ip from managedhost where status = 'Active'" | head -n -1)

    if [ "$SPILLOVERRESULT" != "HOSTNAME,SPILLOVER\n" ]
    then
        echo -e "$red[-] There are spillover queues$reset"
        echo -e "$SPILLOVERRESULT" | column -t -s ',' | sed 's/^/    /'
    else
        echo -e "$green[+] No spillover queue$reset"
    fi
    if [ "$SSHFAILURE" != "" ]
    then
        echo -e "\t${red}*** Cannot connect to '$(echo -e $SSHFAILURE | sed 's/,$//')' on SSH ***"
    fi
    # Mail Queue Status
    MAILQCOUNT=$(mailq | grep -c "^[A-F0-9]")
    MAILSERVERIP=$(cat /etc/postfix/main.cf | grep -i 'relayhost=' | grep -Eo "([0-9]{1,3}[\.]){3}[0-9]{1,3}")
    if [ "$?" ==  "1" ]
    then
        MAILSERVERIP="Not found on /etc/postfix/main.cf"
    fi
    
    if [ "$MAILQCOUNT" -eq "0" ]
    then
        echo -e "$green[+] No mail queue$reset"
    else
        PORTCHECK=$(nc -z $MAILSERVERIP 25 >/dev/null 2>&1;echo $?)
        if [ "$PORTCHECK" == "0"  ]
        then
            echo -e "$red[-] There are $MAILQCOUNT mails on queue. QRadar can connect mail server($MAILSERVERIP) on port 25, there may be relay access problem.$reset"
        else
            echo -e "$red[-] There are $MAILQCOUNT mails on queue. QRadar cannot connect mail server($MAILSERVERIP) on port 25$reset"
        fi
    fi
    ####################################################################################################################################




    # HA status
    hasHA=$(/opt/qradar/ha/bin/ha cstate >/dev/null 2>&1; echo $?)
    if [ $hasHA == "0" ]
    then
        HAinfo=$(/opt/qradar/ha/bin/ha cstate | head -n 2 | awk '{print $1" "$2" "$3}' | sed 's/^/    /')
        resultActive=$(/opt/qradar/ha/bin/ha cstate | head -n 2 | awk '{print $1" "$2" "$3}' | grep 'ACTIVE' >/dev/null 2>&1; echo $?)
        resultStandby=$(/opt/qradar/ha/bin/ha cstate | head -n 2 | awk '{print $1" "$2" "$3}' | grep 'STANDBY' >/dev/null 2>&1; echo $?)
        if [ $resultActive == "0" ] && [ $resultStandby == "0" ]
        then
            echo -e "$green[+] HA is working properly$reset"
        else
            echo -e "$red[-] HA is not working properly.$reset\n$HAinfo"
        fi
    else
        echo -e "$green[+] This is not HA deployment$reset"
    fi
    ####################################################################################################################################

else
    echo "It is not console!"
fi
