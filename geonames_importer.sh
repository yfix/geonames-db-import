#!/bin/bash

# Default values for database variables.
dbhost="localhost"
dbport=3306
dbname="geonames"

logo() {
    echo
	echo "================================================================================================"
	echo "                           G E O N A M E S    D A T A    I M P O R T E R                        "
	echo "================================================================================================"
}

usage() {
	logo
	echo
	echo "Usage: " $0 "-a <action> -u <user> -p <password> -h <host> -r <port> -n <dbname>"
	echo
	echo " This is to operate with the geographic database"
    echo " Where <action> can be one of this: "
	echo "    download-data     Downloads the last packages of data available in GeoNames."
    echo "    create-db         Creates the mysql database structure."
    echo "    create-tables     Creates the mysql tables with no data."
    echo "    import-dumps      Imports geonames data into db. A database is previously needed for this to work."
	echo "    drop-db           Removes the db completely."
    echo "    truncate-db       Removes geonames data from db."
    echo "    split-tables      Split tables into more specific entities."
    echo
    echo " The rest of parameters indicates the following information:"
	echo "    -u <user>     User name to access database server."
	echo "    -p <password> User password to access database server."
	echo "    -h <host>     Data Base Server address (default: localhost)."
	echo "    -r <port>     Data Base Server Port (default: 3306)"
	echo "    -n <dbname>   Data Base Name for the geonames.org data (default: geonames)"
	echo "================================================================================================"
    exit -1
}

download_geonames_data() {
	echo "Downloading GeoNames.org data ..." 

	wget -N http://download.geonames.org/export/dump/admin1CodesASCII.txt -O ./data/admin1CodesASCII.txt
	wget -N http://download.geonames.org/export/dump/admin2Codes.txt -O ./data/admin2Codes.txt
	wget -N http://download.geonames.org/export/dump/featureCodes_en.txt -O ./data/featureCodes_en.txt
	wget -N http://download.geonames.org/export/dump/timeZones.txt -O ./data/timeZones.txt
	wget -N http://download.geonames.org/export/dump/countryInfo.txt -O ./data/countryInfo.txt
	if [ ! -f ./data/allCountries.txt ]; then
		wget -N http://download.geonames.org/export/dump/allCountries.zip -O ./data/allCountries.zip
	    unzip -o ./data/allCountries.zip -d ./data/
	    rm ./data/allCountries.zip
	fi
	if [ ! -f ./data/alternateNames.txt ]; then
		wget -N http://download.geonames.org/export/dump/alternateNames.zip -O ./data/alternateNames.zip
		unzip -o ./data/alternateNames.zip -d ./data/
		rm ./data/alternateNames.zip
	fi
	if [ ! -f ./data/hierarchy.txt ]; then
		wget -N http://download.geonames.org/export/dump/hierarchy.zip -O ./data/hierarchy.zip
		unzip -o ./data/hierarchy.zip -d ./data/
		rm ./data/hierarchy.zip
	fi
	if [ ! -f ./data/postalCodes/allCountries.txt ]; then
		wget -N http://download.geonames.org/export/zip/allCountries.zip -O ./data/postalCodes/allCountries.zip
	    unzip -o ./data/postalCodes/allCountries.zip -d ./data/postalCodes/
		rm ./data/postalCodes/allCountries.zip
	fi
}

if [ $# -lt 1 ]; then
	usage
	exit 1
fi

logo

# Deals with operation mode 2 (Database issues...)
# Parses command line parameters.
while getopts "a:u:p:h:r:n:" opt; 
do
    case $opt in
        a) action=$OPTARG ;;
        u) dbusername=$OPTARG ;;
        p) dbpassword=$OPTARG ;;
        h) dbhost=$OPTARG ;;
        r) dbport=$OPTARG ;;
        n) dbname=$OPTARG ;;
    esac
done


case $action in
    download-data)
        download_geonames_data
        exit 0
    ;;
esac

if [ -z $dbusername ]; then
    echo "No user name provided for accessing the database. Please write some value in parameter -u..."
    exit 1
fi

echo "Database parameters being used..."
echo "Action: " $action
echo "Username: " $dbusername
echo "Password: " $dbpassword
echo "DB Host: " $dbhost
echo "DB Port: " $dbport
echo "DB Name: " $dbname

mysql="mysql -h $dbhost -P $dbport -u $dbusername -p$dbpassword"

case "$action" in
    create-db)
        echo "Creating database $dbname..."
        $mysql -Bse "CREATE DATABASE IF NOT EXISTS $dbname DEFAULT CHARACTER SET utf8;"
    ;;

    create-tables)
        echo "Creating geonames tables into $dbname..."
        $mysql -Bse "USE $dbname;"
        $mysql $dbname < ./sql/geonames_db_struct.sql
    ;;

    import-dumps)
        echo "Importing geonames dumps into database $dbname"
        $mysql --local-infile=1 $dbname < ./sql/geonames_import_data.sql
    ;;
   
    drop-db)
        echo "Dropping $dbname database"
        $mysql -Bse "DROP DATABASE IF EXISTS $dbname;"
    ;;
        
    truncate-db)
        echo "Truncating \"geonames\" database"
        $mysql $dbname < ./sql/geonames_truncate_db.sql
    ;;

    split-tables)
        echo "Splitting tables by geo entities"
        $mysql $dbname < ./sql/geonames_split_tables.sql
    ;;

esac

if [ $? == 0 ]; then 
	echo "[OK]"
else
	echo "[FAILED]"
fi

exit 0
