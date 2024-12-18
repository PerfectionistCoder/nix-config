BACKUP_HOME=${BACKUP_HOME?-'Missing variable BACKUP_HOME'}
BACKUP_VIEW=${BACKUP_VIEW?-'Missing variable BACKUP_VIEW'}
archive=${1?-'Missing name of archive'}

cd $BACKUP_HOME

if [ -d $BACKUP_VIEW ]; then
	rm -rf ./$BACKUP_VIEW/*
else
	mkdir $BACKUP_VIEW
fi

tar --force-local -xzf $archive -C $BACKUP_VIEW
