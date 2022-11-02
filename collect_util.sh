#!bin/bash
trap break INT
#fucntion collector
function_collector() {
        #open file config
        file_config_deviceA="$(cat port_chech_deviceA)"
        file_config_deviceB="$(cat port_chech_deviceB)"
        file_config_deviceC="$(cat port_chech_deviceC)"
        echo "$ip will be start collecting data"
        #snmp to host
        snmpget -v 2c -c xxxxx $ip sysDescr.0 sysName.0 > query.txt
        hostname="$(cat query.txt | tail -1 | cut -c 33-100)"
        brand="$(cat query.txt | grep -i deviceA | wc -l)"
        brand1="$(cat query.txt | grep -i deviceB | wc -l)"
        #get infromation from routing protocol
        if [ $brand -gt 0 ]
        then
                expect grab.exp "$file_config_deviceA $ip" > temp #remote to host colect informaton from igp output wil be save to file temp
                func_config_get_util
        elif [ $brand1 -gt 0 ]
        then
                expect grab.exp "$file_config_deviceB $ip" > temp #remote to host colect informaton from igp output wil be save to file temp
                func_config_get_util
        else
                expect grab.exp "$file_config_deviceC $ip" > temp #remote to host colect informaton from igp output wil be save to file temp
                func_config_get_util
        fi
}

func_config_get_util() {
        >interface_util #errace interface_util file
        brand="$(cat temp | grep -i "eth 1/\|eth 2/\|eth 3/\|eth 0/" | wc -l)"
        brand1="$(cat temp | grep -i "100GE\|ge0/\|ge1/\|ge2/\|ge3/\|Eth-" | wc -l)"
        if [[ $brand -gt 0 ]]
        then
                cat temp | grep -i eth | sed 's/.*eth//' | cut -c 1-6 | sed 's/ *$//g' | sed 's/.//' > list_interface #get list interface
                cat temp | grep -i eth | cut -c 16-25 | awk '$1=$1' > temp7 #get list interface
                echo "show interfaces brief wide | exclude Disable|Down | i BB" # interface_util #write command to file for next process
                for i in $(cat list_interface);
                do 
                        echo "show interface eth $i | i util" >> interface_util #interface_util #write command to file for next process
                done
        elif [[ $brand1 -gt 0 ]]
        then
                cat temp | grep -i "100GE\|ge0/\|ge1/\|ge2/\|ge3/\|Eth-" | cut -d " " -f2 | cut -c 1-10 | awk '$1=$1' > temp7
                var1="$(cat temp7 | grep -i eth- | wc -l)"
                var2="$(cat temp7 | grep -i 100GE | wc -l)"
                if [ $var1 -gt 0 ]
                then
                        cat temp | grep -i "Eth-" | cut -d " " -f2 | cut -c 1-10 | awk '$1=$1' > list_interface 
                else
                        cat temp | grep -i "ge0/\|ge1/\|ge2/\|ge3/" | sed 's/.*GE//' | cut -c 1-10 | awk '$1=$1' > list_interface       
                fi
                for i in $(cat list_interface);
                do
                        if [[ $i =~ "/" ]]
                        then
                                echo "dis interface gi$i | i rate | e peak|util" >> interface_util # interface_util #write command to file for next process
                                echo "dis interface description | i $i | i BB" >> interface_util # interface_util #write command to file for next process
                        else  
                                echo "dis interface $i | i rate | e peak|util" >> interface_util # interface_util #write command to file for next process
                                echo "dis interface description | i $i | i BB" >> interface_util # interface_util #write command to file for next process
                        fi
                done
        else
                cat temp | grep -i "et-\|xe-\|ge-\|ae." | cut -d "." -f1 > list_interface
                for i in $(cat list_interface);
                do 
                        echo "show interface $i | match rate" >> interface_util # interface_util #write command to file for next process
                done
        fi
}

func_get_util() {
        file_config="$(cat interface_util)"
        expect grab.exp "$file_config" $1 > temp2 #remote to host and get utility base on interface and save to file temp2
        func_finishing
}

func_finishing() {
        now=$(date | cut -c 5-14)
        hostname="$(cat query.txt | tail -1 | cut -c 33-100)"
        checking="$(cat temp2 | grep -i "eth 1/\|eth 2/\|eth 3/\|eth 0/" | wc -l)"
        checking1="$(cat temp2 | grep -i "100GE\|ge0/\|ge1/\|ge2/\|ge3/\|Eth-" | wc -l)"
        if [ $checking -gt 0 ]
        then
                cat temp2 | grep -i bits | sed 's/.*://' | sed 's/,*.//' | sed 's/,.*//' > temp3
                cat temp2 | grep -i BB_ | cut -d "_" -f5 > temp6
        elif [ $checking1 -gt 0 ]
        then
                cat temp2 | grep -i bits | sed 's/.*rate: //' | sed 's/,.*//' | sed 's/.*rate //' > temp3
                cat temp2 | grep -i BB_ | cut -d "_" -f5 > temp6
        else
                cat temp2 | grep -i bps | sed 's/.*://' | sed 's/,*.//' | sed 's/(.*//' > temp3
                cat temp | grep -i "et-\|xe-\|ge-\|ae." | awk "/$1/ { print \$(NF - 4); }" > temp6     
        fi
        awk 'ORS=NR%2?FS:RS' temp3 > temp4 #move from row to collum ever 2 list
        if [ $checking -gt 0 ]
        then
                paste temp7 temp4 temp6 > temp5 #merge file to 1 file
        elif [ $checking1 -gt 0 ]
        then
                paste temp7 temp4 temp6 > temp5 #merge file to 1 file
        else
                paste list_interface temp4 temp6 > temp5 #merge file to 1 file
        fi
        sed 's/^/'$hostname' /' temp5 | awk '$1=$1' >> result.txt  #isert hostname to file temp5 and save to file result.txt also remove space     
}


while IFS= read -r ip; do #open file and store to variable ip

    if ping -q -W 1 -c2 "$ip" &>/dev/null; then #confition
        function_collector
        func_get_util "$ip"
        echo "$ip has been done collected $hostname"
    else
        echo "$ip unreachable"  #result if devices down
    fi

done <~/host.txt
trap - INT
sleep 1
