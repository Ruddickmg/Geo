Geo
===

GDAL ogr2ogr Docker container built on Ubuntu 14.4, can automatically download and import all shape files for city, state, county, upper and lower districts, and district subdivisions from the us census into a mysql database

This container was built with the specific purpose of automatically downloading and importing shape files from the US census website, but can be modified to do other things, which I may or may not do myself in the future. 

The container will connect to an sql database container that it has been linked to and use that containers environment variables allongside GDAL:ogr2ogr to import US census shape files. ogr2ogr needs environment variabls of PASSWORD, DBNAME and USER to be set in the linked database container, or have those variables set in its Docker run command in order to function properly.

The Geo container will search for a directory in its /var/www directory called 'shapes' and all shapefiles will be downloaded to that location 

There are a few environment variables that can be set to achieve specific goals:

'SHAPES' 
-
Will accept an array of values: 'city,county,state,division,district' which can either all be set or any combination of each. each value will get its respective shapefile.

For exampe:
'SHAPES=city,county' will download all the city and county shapefiles for the United States and import them into tables with their names

The "division" value represents county sub divisions, and will download all the shape files for county sub divisions in the united states

The process of downloading all the shapefiles can take time, therefore if you have already donwloaded the shapefiles then you can ommit the 'SHAPES' variable and run 'IMPORT' to import existing shape files. 

'IMPORT'
-
Can be set to anything and will use the connection data from the linked database container to connect and import the shape files it finds in the 'shapes' directory into its linked database or databases. 

'IMPORT' can also be ommitted if importing the shapefiles is not the desired action

'DATABASE' 
-
Can be set if a custom database name(s) not specified by the linked container is desired, the name or array of names will be used as the destination of the shape files import into the sql database

'HOST','PORT','USER', 'PASSWORD' and 'DBNAME' 
-
( note: setting 'DBNAME' will set that name to a variable that will be overridden by the 'DATABASE' environment variable, in this case it would be best to use 'DATABASE' to define the databases that will be imported to )

Can be set if linked container does not contain those environment variables, or the database being used is not in a container that can be linked to.

All of these environment variables can be stringed together, for example:

Docker RUN -d -v shapefile/diretory/path:/var/www -e SHAPES=city,county,state,division,district -e IMPORT=yes -e DATABASE=dbname,dbname2 -e HOST=0.0.0.0 -e PORT=3306 -e PASSWORD=password -e USER=user --link database:geo repo/name:tag

would set all connection variables and download and import all shapefiles, however, the easiest way and its intended use is simply to link to the database container(s), in which case only the 'SHAPES' and 'IMPORT' varables need be specified respectively...

And thats how the geo container works!
