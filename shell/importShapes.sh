# if any shape files have been specified for download then attempt to import them
if [[ ! -z "$IMPORT" ]] 
then
	echo " "
	echo " -----------------------------------------------------------------------"
	echo "|                                import                                 |"
	echo " -----------------------------------------------------------------------"
	echo " "

	# get dbc connection variables
	Name=$(env | egrep 'ADDR' | egrep -o '^[^_]+' | grep -v -E '(HOSTNAME=|TERM|PWD|SHLVL|HOME|PATH)') 

	for Alias in $Name;
	do
		# "Hname", "Port" and "Addr" are the host name, port and ip address of the linked connection being evaluated 
		Host=$(env | grep $Alias'_ENV_HOSTNAME=' | grep -o '=.*' | tr -d '", =') 
		Port=$(env | egrep 'PORT='| egrep $Alias | egrep -v ':' | egrep -o '=.*' | tr -d '=')
		Addr=$(env | egrep $Alias'_PORT_'$Port'_TCP_ADDR=' | grep -o '=.*' | tr -d '=')
		Pwd=$( env | grep $Alias'_ENV_PASSWORD=' | grep -o '=.*' | tr -d '", =')
		User=$( env | grep $Alias'_ENV_HUSER=' | grep -o '=.*' | tr -d '", =')
		Extdbname=$(env | grep $Alias'_ENV_DBNAME=' | grep -o '=.*' | tr -d '", =')	

		IFS=',' read -a shapeDB <<< "$DATABASE"
		
		# get an array of which databases to install the shape files to
		if [ -z	"$DATABASE" ] 
		then
			dbn=$Extdbname # try to use database name defined in linked container if not defined in "$DATABASE" env variable
		else
			dbn="${shapeDB[@]}" # set custom database name(s) to import to if wanted
		fi
			
		for dbName in $dbn
		do			
			x=0
			until [[ ! -z $( mysql -h "$Addr" -P "$Port" -u"$User" -p"$Pwd" -B -e "show databases" 2>/dev/null | grep "$dbName" ) ]]
			do 
				sleep 1
				
				x=$(($x+1))
				if [[ "$x" -gt "60" ]]
				then
					break
				fi
			done

			# if the database that is being attempted to write to exists then continue
            if [[ ! -z $( mysql -h "$Addr" -P "$Port" -u"$User" -p"$Pwd" -B -e "show databases" 2>/dev/null | grep "$dbName" ) ]]
		    then
		    	# get the paths to all the shape files that need to be uploaded
				shapez=$( find $shapeFileDir -name "*.shp" )
		
				# if there are shapefiles to import then report results and continue
				if [[ -z "$shapez" ]] 
				then 
					echo '  - No shapefiles found'
				else
					echo -n -e "  - Importing shapefiles to $Host..."
					
					# for each shape file found define the table name and the name for the geo table
					x=0
					for shape in $shapez
					do
						x=$(($x + 1))
					    shapeName=$( basename $( echo "$shape" | sed -e "s/\/[^\/]*$//" ) .deb )
					    	case "$shapeName" in
					    	'senate')
					    		tableName='district_upper_shape_files'
					    		geoName='district_upper_geo'
					    		;;
		    		    	'house')
								tableName='district_lower_shape_files'
								geoName='district_lower_geo'
		    				    ;;
		    	   			'county')
				    		    tableName='county_shape_files'
				    		    geoName='county_geo'
	    			    		;;
	    			    	'division')
	    					    tableName='county_subdivision_shape_files'
	    					    geoName='county_subdivision_geo'
	    	    			    ;;
							'city')
		       			 		tableName='city_shape_files'
		       			 		geoName='city_geo'
		       		 			;;
			       		 	'state')
			       		    	tableName='state_shape_files'
			       		    	geoName='state_geo'
				   		    	;;
						esac
	
						# if the shape file being uploaded is from the same place as the one before it then add it to the same table as the preceding shape file
						if [ $x > 1 ] && [ "$shapeName" == "$previous" ]
						then
						    ogr2ogr -f 'MYSQL' MYSQL:"$dbName",user="$User",host="$Addr",password="$Pwd",port="$Port" "$shape" -append -nln "$tableName" > /dev/null 2>&1 || status=' import failed'
						
						#if the table already exists in the specified database then update the table
						elif [[ ! -z $( mysql -h "$Addr" -P "$Port" -u"$User" -p"$Pwd" -e "SELECT * FROM information_schema.tables WHERE table_schema = '$dbName' AND table_name = '$tableName'"; ) ]]
						then
							ogr2ogr -f 'MYSQL' MYSQL:"$dbName",user="$User",host="$Addr",password="$Pwd",port="$Port" "$shape" -update -nln "$tableName" -lco MYSQL_FID=id -lco MYSQL_GEOM_COLUMN="$geoName" -lco ENGINE=MYISAM > /dev/null 2>&1 || status=' import failed'
						
						#if the table does not exist then create the table
						else
							ogr2ogr -f 'MYSQL' MYSQL:"$dbName",user="$User",host="$Addr",password="$Pwd",port="$Port" "$shape" -nln "$tableName" -lco MYSQL_FID=id -lco MYSQL_GEOM_COLUMN="$geoName" -lco ENGINE=MYISAM > /dev/null 2>&1 || status=' import failed'
						fi
						
						# keep track of what shape file was imported before, so that if the following shape file is the same they can be imported into the same table
						previous=$shapeName
					done
										
					# report results
					if [[ "$status" == " import failed" ]]
					then
					    echo -e "$status\n"
					else
					    echo -e " success\n"
					fi
				fi
			else
				echo -e "  - Database \"$dbName\" was not found in MariaDB\n"
			fi
		done	
	done
fi