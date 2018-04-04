#!/bin/sh

confpath=/usr/src/sys/arch/$(machine)/conf
generic=$confpath/GENERIC
newconf=$confpath/NEW

[ -f $newconf ] && rm -f $newconf
sed -n '/^machine/,/^mainbus/p' $generic > $newconf

if [ $(sysctl -n hw.ncpu) -gt 1 ]; then
	sed -i '/^mainbus/d' $newconf
	echo 'option MULTIPROCESSOR' >> $newconf
	echo 'cpu* at mainbus?' >> $newconf
fi

dmesg |sed -rn 's/^([a-z]+)([0-9]) at (root|[a-z]+)([0-9])?.*$/\1:\2:\3:\4/p' | \
while IFS=: read -r part partno bus busno; do 
	targets="${bus}\? ${bus}${busno}"
	( [ ${part} = scsibus ] || [ ${part} = cpu ] ) && continue
	[ ${bus} = root ] && targets=root
	sources="${part}\* ${part}${partno}"

	for source in $sources; do
		for target in $targets; do
			sed -n "/^${source}.*at ${target}/p" $generic
		done
	done |sort -u >> $newconf
done
