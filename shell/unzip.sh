if [ ! -z "$ZIP" ]
then
	# Find shape files
	shapefiles=$( find "$( find /var/www -name 'shapes' )" -name "*.zip" )

	if [[ ! -z "$shapefiles" ]]
	then	
		echo -n '  - unpacking shape files...'
	    for shapefile in $shapefiles
	    do
			cd $( echo "$shapefile" | sed -e "s/\/[^\/]*$//" )
	    	unzip -oq "$shapefile" > /dev/null 2>&1 && rm "$shapefile" || stat=' unzip failed'
	    done
	    
	    if [[ "$stat" == " unzip failed" ]]
		then
			echo $stat
		else
		    echo ' success'
		fi
	fi
	
	ipZipGeocodes=$( find tmp -name "*.zip" )
	if [ ! -z "$ipZipGeocodes" ]
	then
		echo -n ' - unpacking geo codes for ip/zip code identification'
		unzip -oq "$ipZipGeocodes" > /dev/null 2>&1 && echo ' success' || stat=' unzip failed'
	fi
fi