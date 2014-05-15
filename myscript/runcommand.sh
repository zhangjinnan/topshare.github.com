!/bin/bash

for i in `cat host.txt`
do
	ssh root@$i "$1"
done

exit 0
