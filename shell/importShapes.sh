# if any shape files have been specified for download then attempt to import them
if [[ ! -z "$IMPORT" ]] 
then
	echo " "
	echo " -----------------------------------------------------------------------"
	echo "|                                import                                 |"
	echo " -----------------------------------------------------------------------"
	echo " "

	# get dbc connection variables
	Name=$( env | egrep 'ADDR' | egrep -o '^[^_]+' | grep -v -E '(HOSTNAME=|TERM|PWD|SHLVL|HOME|PATH)') 

	for Alias in $Name;
	do
		# "Hname", "Port" and "Addr" are the host name, port and ip address of the linked connection being evaluated 
		Hname=$(env | grep $Alias'_ENV_HOSTNAME=' | grep -o '=.*' | tr -d '", =') 
		Port=$(env | egrep 'PORT='| egrep $Alias | egrep -v ':' | egrep -o '=.*' | tr -d '=' | sed 's/[^0-9]*//g' )
		Addr=$(env | egrep $Alias'_PORT_'$Port'_TCP_ADDR=' | grep -o '=.*' | tr -d '=')
		Pwd=$( env | grep $Alias'_ENV_PASSWORD=' | grep -o '=.*' | tr -d '", =')
		User=$( env | grep $Alias'_ENV_HUSER=' | grep -o '=.*' | tr -d '", =')
		Extdbname=$(env | grep $Alias'_ENV_DBNAME=' | grep -o '=.*' | tr -d '", =')	

		# get an array of which databases to install the shape files to
		if [ -z	"$DATABASE" ] 
		then
			dbn=$Extdbname # try to use database name defined in linked container if not defined in "$DATABASE" env variable
		else
			IFS=',' read -a shapeDB <<< "$DATABASE"
			dbn="${shapeDB[@]}" # set custom database name(s) to import to if wanted
		fi
		
		for dbName in $dbn
		do		
			export PGPASSWORD=$Pwd
			x=0
			until \
			[[ "$Hname" == "mysql" ]] && [[ ! -z `mysql -h "$Addr" -P "$Port" -u"$User" -p"$Pwd" -B -e "show databases" 2>/dev/null | grep "$dbName"` ]] || \
			[[ "$Hname" == "postgres" ]] && [[ ! -z `psql --host="$Addr" --port="$Port" --user="$User" -wlqt 2>/dev/null | cut -d \| -f 1 | grep "$dbName"` ]]
			do 
				sleep 1
				x=$(($x+1))
				if [[ "$x" -gt "60" ]]
				then
					skip='yes'
					break
				fi
			done
			
			# if the database that is being attempted to write to exists then continue
            if [[ -z "$skip" ]]
		    then 	
		    	if [ ! -z "$SHAPES" ]
		    	then	
			    	if [[ "$Hname" == "postgres" ]];then
						echo -n "  - Creating postgis extensions in $dbName..."
						psql -q --host="$Addr" --port="$Port" --user="$User" -d "$dbName" -c "CREATE EXTENSION postgis;" > /dev/null 2>&1 || stat='  - failed to create postgis extension'
						psql -q --host="$Addr" --port="$Port" --user="$User" -d "$dbName" -c "CREATE EXTENSION postgis_topology;" > /dev/null 2>&1 || stat='  - failed to create postgis_topology extension'
						psql -q --host="$Addr" --port="$Port" --user="$User" -d "$dbName" -c "CREATE EXTENSION fuzzystrmatch;" > /dev/null 2>&1 || stat='  - failed to create fuzzystrmatch extension'
						psql -q --host="$Addr" --port="$Port" --user="$User" -d "$dbName" -c "CREATE EXTENSION postgis_tiger_geocoder;"  > /dev/null 2>&1 || stat='  - failed to create postgis_tiger_geocoder extension'
				
						if [[ -z "$stat" ]]; then
							echo ' success'
						else
							echo -e " \n"
							for failed in "$stat"
							do
								echo "$failed"
							done
						fi
					fi		    	
		    
		    		# get the paths to all the shape files that need to be uploaded
					shapez=$( find $( find /var/www -name 'shapes' ) -name "*.shp" )
			
					# if there are shapefiles to import then report results and continue
					if [[ -z "$shapez" ]] 
					then 
						echo '  - No shapefiles found'
					else
						echo -n -e "  - Importing shapefiles to $Hname..."
						
						# for each shape file found define the table name and the name for the geo table
						x=0
						for shape in $shapez
						do
							x=$(($x + 1))
						    shapeName=$( basename $( echo "$shape" | sed -e "s/\/[^\/]*$//" ) .deb )
						    case "$shapeName" in
							'senate')
					    		tableName='upper_districts'
					    		geoName='district_geo'
					    		;;
		    		    	'house')
								tableName='lower_districts'
								geoName='district_lower_geo'
		    				    ;;
		    	   			'county')
				    		    tableName='counties'
				    		    geoName='county_geo'
	    		    			;;
	    		    		'division')
	    					    tableName='subdivisions'
							    geoName='subdivision_geo'
    	    				    ;;
							'city')
		       			 		tableName='cities'
		       					geoName='city_geo'
		       	 				;;
			   		 		'state')
		       		    		tableName='states'
		       		    		geoName='state_geo'
			   		    		;;
							esac
				
							if [[ "$Hname" == "postgres" ]]
							then
								# set encoding for shapefile import
								#export PGCLIENTENCODING=ISO_8859_7
								export PGCLIENTENCODING=LATIN1

								# check if the table exists in the database
								dbExists=`psql -q --host="$Addr" --port="$Port" --user="$User" -d $dbName -c "\d+ $tableName"` || dbExists='empty'  
							
								# if the shape file being uploaded is from the same place as the one before it then add it to the same table as the preceding shape file
								if [ $x > 1 ] && [ "$shapeName" == "$previous" ]
								then
									ogr2ogr -f PostgreSQL PG:"host='$Addr' port='$Port' user='$User' password='$Pwd' dbname='$dbName'" "$shape" -append -nln "$tableName" -lco FID='id' -lco ENCODING='LATIN1' -nlt PROMOTE_TO_MULTI -q > /dev/null 2>&1 || status=" an import into $tableName failed"

								#if the table does not exist then create the table
								elif [[ "$dbExists" == "empty" ]]
								then
									ogr2ogr -f PostgreSQL PG:"host='$Addr' port='$Port' user='$User' password='$Pwd' dbname='$dbName'" "$shape" -nln "$tableName" -lco FID='id' -lco ENCODING='LATIN1' -nlt PROMOTE_TO_MULTI -q > /dev/null 2>&1 || status=" an import into $tableName failed"
								
								#if the table already exists in the specified database then update the table
								else
									ogr2ogr -f PostgreSQL PG:"host='$Addr' port='$Port' user='$User' password='$Pwd' dbname='$dbName'" "$shape" -update -nln "$tableName" -lco FID='id' -lco ENCODING='LATIN1' -nlt PROMOTE_TO_MULTI -q > /dev/null 2>&1 || status=" an import into $tableName failed"
								fi
								
								unset PGCLIENTENCODING=LATIN1
							elif [[ "$Hname" == "mysql" ]]
							then
								# if the shape file being uploaded is from the same place as the one before it then add it to the same table as the preceding shape file
								if [ $x > 1 ] && [ "$shapeName" == "$previous" ]
								then
									ogr2ogr -f MYSQL MYSQL:"dbname=$dbName",user="$User",host="$Addr",password="$Pwd",port="$Port" "$shape" -append -nln "$tableName" > /dev/null 2>&1 || status=" an import into $tableName failed"
								
								#if the table already exists in the specified database then update the table
								elif [[ ! -z `mysql -h "$Addr" -P "$Port" -u"$User" -p"$Pwd" -e "SELECT * FROM information_schema.tables WHERE table_schema = '$dbName' AND table_name = '$tableName'";` ]]
								then
									ogr2ogr -f MYSQL MYSQL:"dbname=$dbName",user="$User",host="$Addr",password="$Pwd",port="$Port" "$shape" -update -nln "$tableName" -lco ENGINE=MYISAM > /dev/null 2>&1 || status=" an import into $tableName failed"
								
								#if the table does not exist then create the table
								else
									ogr2ogr -f MYSQL MYSQL:"dbname='$dbName',user='$User',host='$Addr',password='$Pwd',port='$Port'" "$shape" -nln "$tableName" -lco ENGINE=MYISAM > /dev/null 2>&1 || status=" an import into $tableName failed"
								fi
							fi
								
							# keep track of what shape file was imported before, so that if the following shape file is the same they can be imported into the same table
							previous=$shapeName
						done
										
						# report results
						if [[ ! -z "$status" ]]
						then
							for stat in "$status"
					  	  	do
					  	  		echo -e "$stat\n"
					  	  	done	
						else
							echo -e " success"
						fi
					fi
				fi	
				if [ ! -z "$GEOCODES" ]
				then
					until \
					[[ "$Hname" == "mysql" ]] && [[ ! -z `mysql -h "$Addr" -P "$Port" -u"$User" -p"$Pwd" -B -e "show databases" 2>/dev/null | grep 'geocodes'` ]] || \
					[[ "$Hname" == "postgres" ]] && [[ ! -z `psql --host="$Addr" --port="$Port" --user="$User" -wlqt | cut -d \| -f 1 | grep 'geocodes'` ]]
					do 
						sleep 1
						x=$(($x+1))
						if [[ "$x" -gt "360" ]]
						then
							break
						fi
					done
					
					if [ "$Hname" == "postgres" ]
					then
						echo -n '  - Importing geocodes into PostgreSQL...'
						psql --host="$Addr" --port="$Port" --user="$User" -d $dbName -c "\COPY geocodes (ip_low,ip_high,country_abbreviation,country,state,city,latitude,longitude,zip) FROM '$( find / -name 'geocodes.CSV' )' DELIMITER ',' CSV HEADER;" > /dev/null 2>&1 && echo ' success' || echo ' failed'
					elif [ "Hname" == "mysql" ]
					then
						echo -n '  - Importing geocodes into Mysql...'
						mysqlimport --host="$Addr" --port="$Port" --user="$User" --password="$Pwd" --columns='ip_low,ip_high,country_abbreviation,country,state,city,latitude,longitude,zip' --fields-terminated-by=',' --fields-enclosed-by='"' --lines-terminated-by='\n' --ignore-lines=1 --local "$dbName" '/geocodes.CSV' > /dev/null 2>&1 && echo ' success' || echo ' failed'
					fi
				fi
			else
				echo -e "  - Database \"$dbName\" was not found in MariaDB\n"
			fi
			if [[ "$Hname" == "postgres" ]];then
				unset PGPASSWORD
			fi
		done	
	done
fi