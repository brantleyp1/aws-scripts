# replacevolume.sh

## General

This script was built and used for an issue with the mongo instances for Client Vista. We were taking a snapshot of a volume from one instance, making a new volume of that snapshot, and replacing a volume of another instance with that new volume.

Potentially this could be used for rebuilding faulty volumes, or for something like mounting a volume from an instance that sudo is unavailable on.

## Specifics

There are a couple of variables that have to be filled in. You'll need to know the instance id for the source instance and the target instance. You'll need to know the device name (i.e. /dev/xvdf). Also, the tags are specific to client vista, so you'll need to update accordingly. It wouldnt take much to either have them pulled from another instance/volume/etc, or feed them into the script, but for now they're statically set in the command.
