#!/bin/bash
# Script rear2docker.sh
# Author: gratien dhaese (c) GPL v3 2021
if [[ ! -f /usr/sbin/rear ]] ; then
       echo 'ReaR not installed - exiting'; exit 1
fi
REAR_VERSION=$(/usr/sbin/rear --version | awk '{print $2}')
if [[ -z "$REAR_VERSION" ]] ; then
	echo 'Invalid ReaR version'; exit 1
fi
echo "Running \"rear -d mkrescue\""
/usr/sbin/rear -v -d mkrescue

echo "
	ReaR image created - continue to create a container image
"
DATE=$(date +%Y%m%d)
ROOT_REAR=$(ls -1drt /tmp/rear.* | tail -1)
ROOTFS=$ROOT_REAR/rootfs
DOCKER_IMAGE=rear-${REAR_VERSION}-$(hostname -s)

id=$(tar --numeric-owner -C $ROOTFS -c . | docker import - $DOCKER_IMAGE:$DATE)
# docker tag $id $DOCKER_IMAGE:latest
echo "${DOCKER_IMAGE}:${DATE} with id=${id} created!"
echo "To explore run: docker run -it ${DOCKER_IMAGE}:${DATE} /bin/bash"
echo "
	Entering the container image ${DOCKER_IMAGE}:${DATE}
	It behaves the same as \"chroot $ROOTFS\"
	Type \"exit\" to go back to the normal shell.
	Container ${DOCKER_IMAGE}:${DATE} will be removed automatically.
"
docker run -i -t --rm ${DOCKER_IMAGE}:${DATE} /bin/bash
read -n 1 -t 5 -r -s -p $'Press \"y\" key to chroot $ROOTFS - any other will remove the temporary rear workspace [time-out 5 sec]: ' key
echo
if [[ "$key" = "y" ]]; then
	chroot $ROOTFS
fi
echo "Removing temporary rear workspace $ROOT_REAR"
rm -rf $ROOT_REAR

