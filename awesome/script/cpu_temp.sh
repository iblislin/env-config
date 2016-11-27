sensors | grep temp1 | head -1 | awk '{ str=substr($2, 2, 4); print str "C" }'
