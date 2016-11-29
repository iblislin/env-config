active=$(egrep 'Active:' /proc/meminfo | awk '{print $2}');
total=$(egrep 'MemTotal' /proc/meminfo | awk '{print $2}');
echo $(expr '(' $active \* 100 ')' / $total )%;
