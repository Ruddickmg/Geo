# function that downloads shape files
function getShapeFiles {
	if [[ "$1" != "SLDU" ]]
	then
    	echo -en "  - downloading $3 shapefiles..."     
	fi
	
	# get all the links to each shapefile downoad url and output them to a file entitled "url" 
    wget ftp://ftp2.census.gov/geo/tiger/TIGER2014/$1/ -k -q -O 'url';

	# put all the links into a variable called "getLinks"
    getLinks=$( grep -o "ftp://[^'\"<>]*" 'url' )

	# for each link download it into a file with the name of the type (city, state, etc.. ) and an auto incrementing number
    x=0
    for link in $getLinks
    do
		# if the link has the defining file dir in its path ( used to differentiate between actual download links and other page links ) then download the shape file 
        if [[ "$link" == *$1* ]]
   	    then
   	    	# auto incrementing number
            x=$(($x + 1))
            
            # download the shape file and output it into a zip folder with the path, the type/name and an incremental number
            wget -q $link -O "$2/$3_$x.zip" || statu=' download was unsuccessful'
        fi
    done

	# report status
	if [[ "$statu" == " download was unsuccessful" ]]
	then
        echo "$statu"
	elif [[ "$1" != "SLDU" ]]
	then
        echo ' success'
	fi

	# remove the folder containing the links
	rm url
}

# function that checks if a file exists and creates one if it does not
function makeDir {
	if [[ ! -e "$1" ]]
	then
    	mkdir "$1"
    fi 
}

# if there are shapes specified for download then attempt to download them
if [ ! -z "$DOWNLOAD" ] 
then

	echo " "
	echo " -----------------------------------------------------------------------"
	echo "|                               Download                                |"
	echo " -----------------------------------------------------------------------"
	echo " "

	# Find shape file directory
	shapeFileDir=$( find /var/www -name 'shapes' )

	# get an array of the specified shape files to download	
	IFS=',' read -a shapeFileNames <<< "$SHAPES"

    # If there are shape files load them into their appropriate mysql tables
	for sfdn in "${shapeFileNames[@]}"
	do		
		# define the destination for shape file downloads
        paths="$shapeFileDir/$sfdn"
        
        # create any needed directories that do not already exist 
       	makeDir "$paths"
       	
       	# sort through and download shape files
   	    case $sfdn in
	    	'district')
 	    		makeDir "$paths/senate"
  		        makeDir "$paths/house"
   			    getShapeFiles 'SLDU' "$paths/senate" "$sfdn"
        	    getShapeFiles 'SLDL' "$paths/house" "$sfdn"
    		;;
   		   	'county')
   			    getShapeFiles 'COUNTY' "$paths" "$sfdn" 
            ;;
    		'division')
   		    	getShapeFiles 'COUSUB' "$paths" "$sfdn" 
   			;;
    		'city')
     			getShapeFiles 'PLACE' "$paths" "$sfdn"
 			;;
       	 	'state')
       	 	 	getShapeFiles 'STATE' "$paths" "$sfdn" 
   	 	 	;;
		esac
	done 
fi