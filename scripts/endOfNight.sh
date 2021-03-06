#!/bin/bash

if [ $# -eq 1 ] ; then
	if [ "x$1" = "x-h" ] ; then
		echo "Usage: $BASH_ARGV0 [YYYYmmdd]"
		exit
	else
		LAST_NIGHT=$1
	fi
else
	LAST_NIGHT=$(date -d '12 hours ago' +'%Y%m%d')
fi

source $ALLSKY_HOME/config.sh
source $ALLSKY_HOME/scripts/filename.sh
source $ALLSKY_HOME/scripts/ftp-settings.sh

cd  $ALLSKY_HOME/scripts

# Post end of night data. This includes next twilight time
if [[ $POST_END_OF_NIGHT_DATA == "true" ]]; then
        echo -e "Posting next twilight time to let server know when to resume liveview\n"
        ./postData.sh
	echo -e "\n"
fi

# Uncomment this to scan for, and remove corrupt images before generating
# keograms and startrails. This can take several (tens of) minutes to run
# and isn't necessary unless your system produces corrupt images which then
# generate funny colors in the summary images...
# ./removeBadImages.sh $ALLSKY_HOME/images/$LAST_NIGHT/  

# Generate keogram from collected images
if [[ $KEOGRAM == "true" ]]; then
        echo -e "Generating Keogram\n"
        mkdir -p $ALLSKY_HOME/images/$LAST_NIGHT/keogram/
        ../keogram $ALLSKY_HOME/images/$LAST_NIGHT/ $EXTENSION $ALLSKY_HOME/images/$LAST_NIGHT/keogram/keogram-$LAST_NIGHT.$EXTENSION
        if [[ $UPLOAD_KEOGRAM == "true" ]] ; then
                OUTPUT="$ALLSKY_HOME/images/$LAST_NIGHT/keogram/keogram-$LAST_NIGHT.$EXTENSION"
                if [[ $PROTOCOL == "S3" ]] ; then
                        $AWS_CLI_DIR/aws s3 cp $OUTPUT s3://$S3_BUCKET$KEOGRAM_DIR --acl $S3_ACL &
		elif [[ $PROTOCOL == "local" ]] ; then
                	cp $OUTPUT $KEOGRAM_DIR &
                else
                        lftp "$PROTOCOL"://"$USER":"$PASSWORD"@"$HOST":"$KEOGRAM_DIR" \
                                -e "set net:max-retries 1; put $OUTPUT; bye" &
                fi
        fi
        echo -e "\n"
fi

# Generate startrails from collected images. Threshold set to 0.1 by default in config.sh to avoid stacking over-exposed images
if [[ $STARTRAILS == "true" ]]; then
        echo -e "Generating Startrails\n"
        mkdir -p $ALLSKY_HOME/images/$LAST_NIGHT/startrails/
        ../startrails $ALLSKY_HOME/images/$LAST_NIGHT/ $EXTENSION $BRIGHTNESS_THRESHOLD $ALLSKY_HOME/images/$LAST_NIGHT/startrails/startrails-$LAST_NIGHT.$EXTENSION
        if [[ $UPLOAD_STARTRAILS == "true" ]] ; then
                OUTPUT="$ALLSKY_HOME/images/$LAST_NIGHT/startrails/startrails-$LAST_NIGHT.$EXTENSION"
                if [[ $PROTOCOL == "S3" ]] ; then
                        $AWS_CLI_DIR/aws s3 cp $OUTPUT s3://$S3_BUCKET$STARTRAILS_DIR --acl $S3_ACL &
                elif [[ $PROTOCOL == "local" ]] ; then
                        cp $OUTPUT $STARTRAILS_DIR &
		else
                        lftp "$PROTOCOL"://"$USER":"$PASSWORD"@"$HOST":"$STARTRAILS_DIR" \
                                -e "set net:max-retries 1; put $OUTPUT; bye" &
                fi
        fi

        echo -e "\n"
fi

# Generate timelapse from collected images
if [[ $TIMELAPSE == "true" ]]; then
	echo -e "Generating Timelapse\n"
	./timelapse.sh $LAST_NIGHT
	echo -e "\n"
fi

# Run custom script at the end of a night. This is run BEFORE the automatic deletion just in case you need to do something with the files before they are removed
./endOfNight_additionalSteps.sh

# Automatically delete old images and videos
if [[ $AUTO_DELETE == "true" ]]; then
	del=$(date --date="$NIGHTS_TO_KEEP days ago" +%Y%m%d)
	for i in `find $ALLSKY_HOME/images/ -type d -name "2*"`; do
	  (($del > $(basename $i))) && rm -rf $i
	done
fi
