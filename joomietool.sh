#!/bin/bash -ex
# Program opens with the command joomietool

# Possible commands to add in the future are jht and jstats

### Function to provide database information to all other functions that need it. ###
function dbinfo() {

	#Grabs the Database User
	db_user=$(cat configuration.php 2>/dev/null | grep '$user' | egrep -o "[a-zA-Z0-9]+_[a-zA-Z0-9]+" | tr -d "', ")

	#Grabs the Database Name
	db_name=$(cat configuration.php 2>/dev/null | grep 'db ' | egrep -o "[a-zA-Z0-9]+_[a-zA-Z0-9]+" | tr -d "', ")

	#Grabs the Database Password
	db_password=$(cat configuration.php 2>/dev/null | grep 'password' | egrep -o "'.+'" | cut -c 2- | rev | cut -c 2- | rev)

	#Grabs the Database Prefix
	db_prefix=$(cat configuration.php 2>/dev/null | grep 'prefix' | egrep -o "'.+'" | tr -d "'")

	#Grabs the Database Host
	db_host=$(cat configuration.php 2>/dev/null | grep '$host' | egrep -o "'[a-zA-Z0-9]+" | cut -c 2-)
}

### Function to ensure a consistent message whenever there is no Joomla site present ###
function nojoomie() {
	echo "There is no Joomla site in this directory."
}

### Function to ensure the database is connected properly ###
function dbconnect() {
	result=$(mysql --user="$db_user" --password="$db_password" --host=localhost --database="$db_name" -e "SHOW DATABASES LIKE '$db_name'")

	if [[ $result != *$db_name* ]]
	then
		echo "Unable to connect to $db_name"
		kill -INT $$
	fi
}

### Function for displaying Database Information ###
function jdb() {
	# Help flag
	if [[ $1 == "--help" || $1 == "-h" ]];
	then
		clear
		echo ""
		echo ""
		echo "jdb"
		echo ""
		echo "This tool is used to show the current database information for the specified folder."
		echo ""
		echo "The following flags are available for varied use: "
		echo ""
		echo "	There are none at this time."
		echo ""
		return
	fi

	echo "Processing..."

	dbinfo

	# If statement to see if joomla exists in the current folder or not
	if cat configuration.php >/dev/null 2>&1 ; then	
		echo ""
		echo ""
		echo "          database host: $db_host"
		echo "          database name: $db_name"
		echo "          database user: $db_user"
		echo "      database password: $db_password"
		echo "        database prefix: $db_prefix"
		echo ""
		echo ""
	else
		nojoomie
		return 1
	fi
}

### Function dealing with Joomla core files ###
function jcore() {
	####Restores core files for version 2.5, 3.2, and 3.3

	# Help flag
	if [[ $1 == "--help" || $1 == "-h" ]];
	then
		clear
		echo ""
		echo ""
		echo "jcore"
		echo ""
		echo "This tool is used to update/replace the core files for Joomla and supports all stable versions."
		echo "It's important to note that trying to update between major versions such as 2.x.x to 3.x.x may break the site."
		echo ""
		echo "the following flags are available for varied uses: "
		echo ""
		echo "  -w or --wsod -> This will attempt to fix a Joomla White Screen of Death."
		echo ""
		return
	fi

	# White Screen of Death flag
	if [[ $1 == "--wsod" || $1 == "-w" ]];
	then
		echo "Processing..."
		
		if cat joomla.xml >/dev/null 2>&1 ; then

			currentver=$(cat joomla.xml 2>/dev/null | grep -i version | egrep -o ">[0-9.0-9.0-9]+" | cut -c 2-)

			echo "Did you recently try to change versions?"
			read answer

			if [[ $answer == "yes" ]];
			then
				echo "what version was it before the attempted update? ( Only input the version itself. Ex: 2.5.7 )"
				read priorversion
			else
				clear
				echo "Attempting to restore existing core files.."
				priorversion=$currentver
			fi
		else
			nojoomie
			echo 'If you would like core files installed for a new installation, create a file in the directory called joomla.xml' 
			echo 'and enter "<version>#.#.#</version>" with the version number you want into the file.  Then try again.'
			return 1
		fi

		# If statement to ensure that the version of Joomla they specified actually exists
		if wget http://mirror.myjoomla.io/Joomla_"$priorversion"-Stable-Full_Package.tar.gz -P ./joomla.folder >/dev/null 2>&1 ; then

			# Grabs the joomla package and puts it in a folder called joomla.folder		
			wget http://mirror.myjoomla.io/Joomla_"$priorversion"-Stable-Full_Package.tar.gz -P ./joomla.folder >/dev/null 2>&1

			clear
			echo ""
			echo "Processing..."
			echo ""		

			# Moves into the joomla folder
			cd joomla.folder
	
			# Untars and gunzips the file
			tar -zxf Joomla_"$priorversion"-Stable-Full_Package.tar.gz
	
			# Moves back into the joomla folder
			cd ..
	
			# Makes a new folder to place all the files and folders and copies before we perform the rsync
			rm -rf jcore.oldfiles >/dev/null 2>&1
			mkdir jcore.oldfiles
			rsync -rq --exclude=joomla.folder --exclude=jcore.oldfiles . jcore.oldfiles/
	
			# Removes the library folder so that the rsync can replace with the correct verions library properly.
			rm -rf libraries >/dev/null 2>&1
	
			# Performs the update
			rsync -rq --force joomla.folder/ .
	
			# Removes old folder and file, and moves the installation folder
			rm -rf joomla.folder >/dev/null 2>&1
			rm -rf Joomla_"$priorversion"-Stable-Full_Package.tar.gz >/dev/null 2>&1
			rm -rf installation.old >/dev/null 2>&1
			
			# Only leaves the installation folder in place if Joomla does not already exist. (replacing core files vs. new installation)
			if cat configuration.php >/dev/null 2>&1 ; then
				mv installation{,.old}
			fi
	
			newcurrentver=$(cat joomla.xml | grep -i version | egrep -o ">[0-9.0-9.0-9]+" | cut -c 2-)
	 
			echo "Your Joomla version is "$newcurrentver""
			return	

		else
			echo "That version doesn't exist in our database."
			return 1
		fi
	
	fi

	echo "Processing..."

	# if statement to make sure a joomla install is there
	if cat joomla.xml >/dev/null 2>&1 ; then

		currentver=$(cat joomla.xml | grep -i version | egrep -o ">[0-9.0-9.0-9]+" | cut -c 2-)
	
		if cat configuration.php >/dev/null 2>&1 ; then
			clear
			echo ""
			echo "You are currently on version "$currentver"."  
			echo ""
			echo "It is best not to switch between versions 2.x.x and 3.x.x."
			echo ""
			echo "What version of Joomla core files would you like to have updated? (only input the version itself. ex: 2.5.7 )"
			read version
		else
			clear
			echo "No Joomla site detected, making new installation."
			version=$currentver
		fi
	else
		nojoomie
		echo 'If you would like core files installed for a new installation, create a file in the directory called joomla.xml'
		echo 'and enter "<version>#.#.#</version>" with the version number you want into the file.  Then try again.'
		return 1
	fi

	# if statement to make sure that the specified Joomla version exists in our archive of Joomla versions
	if wget http://mirror.myjoomla.io/Joomla_"$version"-Stable-Full_Package.tar.gz -P ./joomla.folder >/dev/null 2>&1 ; then
		
		#grabs the joomla package and puts it in a folder called joomla.folder
		wget http://mirror.myjoomla.io/Joomla_"$version"-Stable-Full_Package.tar.gz -P ./joomla.folder >/dev/null 2>&1

		clear
		echo ""
		echo "Processing..."
		echo ""

		# Moves into the joomla folder
		cd joomla.folder
		
		# Untars and gunzips the file
		tar -zxf Joomla_"$version"-Stable-Full_Package.tar.gz
		
		# Moves back into the joomla folder
		cd ..
	
		# Makes a new folder to place all the files and folders and copies before we perform the rsync
		rm -rf jcore.oldfiles >/dev/null 2>&1
		mkdir jcore.oldfiles
		rsync -rq --exclude=jcore.oldfiles --exclude=joomla.folder . jcore.oldfiles/
	
		# Performs the update
		rsync -rq --force joomla.folder/ .
	
		# Removes old folder and file, and moves the installation folder
		rm -rf joomla.folder >/dev/null 2>&1
		rm -rf Joomla_"$version"-Stable-Full_Package.tar.gz >/dev/null 2>&1
		rm -rf installation.old >/dev/null 2>&1
		
		# Only leaves the installation folder in place if Joomla does not already exist. (replacing core files vs. new installation)
		if cat configuration.php >/dev/null 2>&1 ; then
			mv installation{,.old} 
		fi

		echo "Your Joomla version is "$version""
	else
		echo "That version doesn't exist in our database."
		return 1
	fi
}


### Function to give information about tool ###
function joomietool() {

	if [[ $1 == "-c" || $1 == "--copyright" ]];
	then
		clear
		echo ""
		echo "						 JOOMIETOOL COPYRIGHT AGREEMENT"
		echo ""
		echo "This AGREEMENT is between me, Colin Hamilton, and the Individual or Organization accessing and otherwise using Joomietool."
		echo "I've put alot of work into this tool, and all that I ask is that you give credit where credit is due. Please don't plagarize"
		echo "or try to sell Joomietool.  I'm a firm believer in open source and hope that you all enjoy my creation."
		echo ""
		return
	fi

	clear	
	echo ' _____                                          __     '
	echo '/\___ \                              __        /\ \    '
	echo '\/__/\ \    ___     ___     ___ ___ /\_\     __\ \ \   '
	echo '   _\ \ \  / __ \  / __ \ /   __ __ \/\ \  / __ \ \ \  '
	echo '  /\ \_\ \/\ \L\ \/\ \L\ \/\ \/\ \/\ \ \ \/\  __/\ \_\ '
	echo '  \ \____/\ \____/\ \____/\ \_\ \_\ \_\ \_\ \____\\/\_\'
	echo '   \/___/  \/___/  \/___/  \/_/\/_/\/_/\/_/\/____/ \/_/'
	echo ""
	echo ""
	echo "Thank you for using the Joomietool!  It is still in its beta stages but we do everything we can to make it safe to use!  We will not make a function usable unless"
	echo "we have tested it and found it to be safe to the website.  However, use at your own risk.  We currently have the following functions available:"
	echo ""
	echo "		juser - changes the username and password used to access the administrator page"
	echo "		jcore - updates the core Joomla files. Supports 2.5, 3.2, and 3.3.  It is not recommended to update between versions such as 2.5.x to 3.2.x"
	echo "		jdb   - shows the database information for the selected joomla folder"
	echo "		jmove - Moves the website from one folder to another."
	echo ""
	echo "Feel free to add the help flag to the function to get more information.  When you have a moment take a gander at my copyright agreement by" 
	echo "adding -c or --copyright to the end of this function."
	echo ""
	return
}

### Function to move a Joomla site from one folder to another ###
function jmove() {

	# Help flag	
	if [[ $1 == "-h" || $1 == "--help" ]];
	then
		echo "jmove"
		echo ""
		echo "This tool will move the website from one folder to another."
		echo ""
		echo "the following flags are available for varied uses: "
		echo ""
		echo "	There are none at this time."
		echo ""
		return
	fi

	
	clear
	echo ""
	echo 'Make sure your desired location has a .htaccess file with the word "joomla" in it or this function will not provide your location as an option.'	
	echo 'Does the desired folder have a .htaccess file with the word "joomla" in it right now?'
	read input

	# if statement to only perform move function if they confirm there is a .htaccess file with the word "Joomla" in it
	if [[ $input == "yes" ]];
	then
		echo "Processing..."

		# Makes sure the current directory has Joomla in it
		if cat configuration.php >/dev/null 2>&1 ; then

			# Finds all .htaccess files from the public_html forward  that have the word "joomla" in them and displays them as options
			PS3="Select DESIRED Joomla Directory: "
			select des in $(find2perl ~/public_html/ -name ".htaccess" -type f | perl | xargs grep -i "joomla" | head -n 10); do test -n "$des" && break; echo "Invalid Selection"; done

			# Final variable to be used as the destination directory for the move
			des2=$(echo $des | egrep -o "[/a-zA-Z0-9_.]+/")

			# Used to make sure there is a .htaccess result with the following if statement
			list=$(find2perl ~/public_html/ -name ".htaccess" -type f | perl | xargs grep -i "joomla" | head -n 10 | wc -l)	

			# if statement to confirm there is at least one .htaccess file with the word "joomla" in it
			if (( $list >= 1 ));
			then
				echo "Processing..."
			
				sed -i s,"tmp_path = '.*'","tmp_path = '"$des2"tmp'", configuration.php	>/dev/null 2>&1
				if [[ $? == 0 ]]; then
					:
				else
					echo "Warning: tmp_path in the configuration.php file couldn't be changed."
				fi
				sed -i s,"log_path = '.*'","log_path = '"$des2"log'", configuration.php >/dev/null 2>&1
				if [[ $? == 0 ]]; then
					:
				else
					echo "Warning: log_path in the configuration.php file couldn't be changed."
				fi

				# Moves content to new place
				mv -f administrator/ $des2 >/dev/null 2>&1
				mv -f bin/ $des2 >/dev/null 2>&1
				mv -f cache/ $des2 >/dev/null 2>&1
				mv -f cli/ $des2 >/dev/null 2>&1
				mv -f components/ $des2 >/dev/null 2>&1
				mv -f configuration.php $des2 >/dev/null 2>&1
				mv -f configuration.php.move $des2 >/dev/null 2>&1
				mv -f error_log $des2 >/dev/null 2>&1
				mv -f .htaccess $des2 >/dev/null 2>&1
				mv -f htaccess.txt $des2 >/dev/null 2>&1
				mv -f images/ $des2 >/dev/null 2>&1
				mv -f includes/ $des2 >/dev/null 2>&1
				mv -f index.php $des2 >/dev/null 2>&1
				mv -f installation.old $des2 >/dev/null 2>&1
				mv -f jcore.oldfiles/ $des2 >/dev/null 2>&1
				mv -f joomla.xml $des2 >/dev/null 2>&1
				mv -f language/ $des2 >/dev/null 2>&1
				mv -f layouts/ $des2 >/dev/null 2>&1
				mv -f libraries/ $des2 >/dev/null 2>&1
				mv -f LICENSE.txt $des2 >/dev/null 2>&1
				mv -f logs/ $des2 >/dev/null 2>&1
				mv -f media/ $des2 >/dev/null 2>&1
				mv -f modules/ $des2 >/dev/null 2>&1
				mv -f plugins/ $des2 >/dev/null 2>&1
				mv -f README.txt $des2 >/dev/null 2>&1
				mv -f robots.txt $des2 >/dev/null 2>&1
				mv -f robots.txt.dist $des2 >/dev/null 2>&1
				mv -f templates/ $des2 >/dev/null 2>&1
				mv -f tmp/ $des2 >/dev/null 2>&1
				mv -f web.config.txt $des2 >/dev/null 2>&1
				
				echo "The files have been successfully moved and the configuration.php file"
				echo "adjusted to reflect the proper directory."

			else
				echo 'There are no .htaccess files with the word "joomla" in them.'
				return 1
			fi
		else
			nojoomie
			return 1
		fi
	else
		echo 'Please add a .htaccess file with the word "joomla" and then come back.'
		return
	fi

}

### Function used to adjust the users of the Joomla website ###
function juser() {

	# Help flag
	if [[ $1 == "--help" || $1 == "-h" ]];
	then
		clear
		echo ""
		echo ""
		echo "juser"
		echo ""
		echo "This tool is used to change the username or password in the database."
		echo ""
		echo "the following flags are available for varied uses: "
		echo ""
		echo "	-n  -> This will create a new administrative user called deleteme with the password deleteme."
		echo "	-d  -> This will delete a username of your choice."
		echo ""
		return
	fi



	# Inject new administrative user flag
	if [[ $1 == "-n" ]];
	then
		echo "Processing..."

		# If statement to make sure Joomla is present in the directory
		if cat configuration.php >/dev/null 2>&1 ; then

			dbinfo

			clear
		

			# Ensures database connects properly
			dbconnect

			echo -n "REPLACE INTO ${db_prefix}users ("id", "name", "username", "email", "password", "block", "sendEmail", "registerDate", "lastvisitDate", "activation", "params") VALUES ('60', 'Super User', 'deleteme', 'user@usersemailaddress', MD5('deleteme'), 'Super Administrator', '0', '0', '2000-01-01 00:00:00', '0000-00-00 00:00:00', '');" | mysql --user="$db_user" --password="$db_password" --host=localhost --database="$db_name"
			if [[ $? == 0 ]]; then
				:
			else
				echo "Something went wrong."
				return 1
			fi
			echo -n "INSERT IGNORE INTO "${db_prefix}user_usergroup_map" ("user_id", "group_id") VALUES(60, 8);" >/dev/null 2>&1 | mysql --user="$db_user" --password="$db_password" --host=localhost --database="$db_name"
			if [[ $? == 0 ]]; then			
				echo "The temp user deleteme has been created with the password deleteme."
			else
				echo "Something went wrong"
				return 1
			fi

			return
		else
			nojoomie
			return 1
		fi
	fi

	# Delete user flag	
	if [[ $1 == "-d" ]];
	then
		echo "Processing..."
		
		# If statement to make sure Joomla is present in the directory
		if cat configuration.php >/dev/null 2>&1 ; then

			dbinfo

			clear
		

			# Ensures database connects properly
			dbconnect

			# This is where we grab the username to log in to their Joomla Site.  This will be needed once they decide what change to make.
			pre_username=$(echo "SELECT username FROM ${db_prefix}users;" | mysql --user="$db_user" --password="$db_password" --host=localhost --database="$db_name")
			username_part1=$(echo "$pre_username" | egrep -v "username" | head -n 10)

			PS3="Select the username you would like to delete: "
			select username in $(echo "$username_part1"); do test -n "$username" && break; echo "Invalid Selection"; done
		
			echo -n "DELETE FROM ${db_prefix}users WHERE username = '"$username"'" | mysql --user="$db_user" --password="$db_password" --host=localhost --database="$db_name" 
			if [[ $? == 0 ]]; then		
				echo ""$username" has been deleted"
			else
				echo "An error has occurred."
				return 1
			fi
			return
		else
			nojoomie
			return 1
		fi	
	fi

	echo "Processing..."
	
	# If statement to make sure Joomla is present in the directory
	if cat configuration.php >/dev/null 2>&1 ; then

		dbinfo

		clear


		# Ensures database connects properly
		dbconnect

		# This asks which function to use
		echo "Would you like to update the username or the password?"
		read input1var

		# While statment to make sure only username and password are legitimate options
		while [[ $input1var != "username" && $input1var != "password" ]];
		do
			echo "Invalid Option!  Try again."
			echo "Would you like to update the username or the password?"
			read input1var
		done
		
		# This is where we grab the username to log in to their Joomla Site.  This will be needed once they decide what change to make.
		pre_username=$(echo "SELECT username FROM ${db_prefix}users;" | mysql --user="$db_user" --password="$db_password" --host=localhost --database="$db_name")
		username_part1=$(echo "$pre_username" | egrep -v "username" | head -n 10)

		clear
		echo "Processing..."
		PS3="Select Username: "
		select username in $(echo "$username_part1"); do test -n "$username" && break; echo "Invalid Selection"; done


		if [[ $input1var == username ]];
		then
			echo "What is the desired username in place of $username?"
			read input2var
			echo -n "UPDATE ${db_prefix}users SET username = '$input2var' WHERE username = '"$username"';" | mysql --user="$db_user" --password="$db_password" --host=localhost --database="$db_name"
			if [[ $? == 0 ]]; then
				echo "All Done!"
			else
				echo "An error has occurred."
				return 1
			fi
		elif [[ $input1var == password ]];
		then
			echo "What is the desired password for $username?"
			read -s input3var
			echo "Enter the password again: "
			read -s secret

			counter=0
			while [[ $input3var != $secret ]];
			do
				echo "Sorry, that didn't match.  Try again: "
				let "counter += 1"
				echo "What is the desired password for $username?"
				read -s input3var
				echo "Enter the password again: "
				read -s secret
				if (( counter == 1 )); then
					echo "Too many failed attempts."
					return 1
				fi
			done

			echo -n "UPDATE ${db_prefix}users SET password = MD5('$input3var') WHERE username = '"$username"';" | mysql --user="$db_user" --password="$db_password" --host=localhost --database="$db_name"
			if [[ $? == 0 ]]; then
				echo "All Done!"
			else
				echo "An error has occurred."
				return 1
			fi
			return
		fi
	
	else
		nojoomie
		return 1
	fi

# End of juser function
}




# Phrase when joomietool.sh is first curled
echo -e "\n\tInjected JoomieTool 2.2 into current bash session, type 'joomietool' for more detail.\n"
unset HISTFILE
