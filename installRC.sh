#!/bin/bash

function greenStr()
{
        echo -e "\033[32m$1 \033[0m"
}

function yellowStr()
{
        echo -e "\033[33m$1 \033[0m"
}

function redStr()
{
        echo -e "\033[31m$1 \033[0m"
}


nginxDataLocation_def="/usr/share/nginx/html"
nginxDataLocation=
routerClientZipFile="routerClient.zip"
routerAdminZipFile="routerAdmin.zip"
routerCenterFile="router.war"
tomcatLocation_def="/home/GRID/RouterCenter/rc"
tomcatLocation=""
configFiles="cloud-config-context.properties devicesynch.properties"
scriptLocation=$(cd `dirname $0`;pwd)
scriptName=$0
rootPath_def="router"
serviceName=""
serviceConfigLocation=""
qaOrAliYun=

function installRouter()
{
	routerType=$1

	yellowStr "Start to install router $routerType"
	while :
	do
		read -p "Please input router $routerType version(1.0.64):" routerVersion
: '
		if [ -z $routerVersion ] ;then
			routerVersion=$nginxDataLocation
		fi
'
		echo "$routerVersion" | grep -o "\([0-9]\{1,3\}\.\)\{2\}[0-9]\{1,3\}">/dev/null
		if [ $? -eq 0 ] ;then
			break;
		else
			redStr "\trouter $routerType version format is invaid,please input again!"
		fi
	done

	if [ "$routerType" == "client" ] ;then
                fileName=$routerClientZipFile
		newRouterFolder=routerClient$routerVersion
		slink="routerClient"
        elif [ "$routerType" == "admin" ] ;then
                fileName=$routerAdminZipFile
		newRouterFolder=routerAdmin$routerVersion
		slink="routerAdmin"
        fi

	#cd $nginxDataLocation
	#mkdir $newRouterFolder
	if [ $qaOrAliYun -eq 0 ] ;then
		while :
		do
			read -p "Please input router $routerType url:" routerZipFileLocation
			if [[ -z $routerZipFileLocation ]] || [[ ! $routerZipFileLocation =~ ^http* ]] || [[ ! $routerZipFileLocation =~ ${fileName}$ ]] ;then
				redStr "\trouter $routerType url is invalid,please input again!"
			else
				break;
			fi
		done
		
	elif [ $qaOrAliYun -eq 1 ] ;then
		while :
		do
                	read -p "Please input router $routerType zip file path(`greenStr $nginxDataLocation`):" routerZipFileLocation
			if [ -z $routerZipFileLocation ] ;then
				routerZipFileLocation=$nginxDataLocation
			fi
		
                	if [ -e $routerZipFileLocation/$fileName ] ;then
				break;
			else
				redStr "\trouter $routerType zip file path is invaid(or not find zip file in the path),please input again!"
			fi
		done
	
	fi

	cd $nginxDataLocation
	if [ -e $newRouterFolder ] ;then
		yellowStr "$nginxDataLocation/$newRouterFolder exist.Delete it..."
		rm -rf $newRouterFolder
	fi
	mkdir $newRouterFolder

	if [ $qaOrAliYun -eq 0 ] ;then
		curl -s -o $fileName $routerZipFileLocation
	elif [ $qaOrAliYun -eq 1 ] ;then
                if [ "$routerZipFileLocation" != "$nginxDataLocation" ] ;then
                        cp $routerZipFileLocation/$fileName ./
                fi
	fi
	yellowStr "Unzip $fileName..."
	unzip -q -d $newRouterFolder $fileName

	#Not have to do following steps in new versions
	: '
	cd $newRouterFolder
	rm -rf `ls -A | grep -v dist`
	filesInDist=$(ls -AlR dist | grep ^- | wc -l)
	foldersInDist=$(ls -AlR dist | grep ^d[-,r] | wc -l)
	yellowStr "\tThere are $filesInDist files and $foldersInDist folders in dist folder"
	yellowStr "\tStart copy files from dist..."
	cp -r dist/. ./
	rm -rf dist
	filesInDist_new=$(ls -AlR | grep ^- | wc -l)
	foldersInDist_new=$(ls -AlR | grep ^d[-,r] | wc -l)
	yellowStr "\tThere are $filesInDist_new files and $foldersInDist_new folders in $newRouterFolder"
	if [ $filesInDist -eq $filesInDist_new ] && [ $foldersInDist -eq $foldersInDist_new ] ;then
		greenStr "Succes to install router $routerType"
	else
		redStr "Fail to install router $routerType"
		return 1
	fi
	'
	cd $nginxDataLocation
	ln -snf $newRouterFolder $slink
	
	yellowStr "Delete $fileName"
	rm -rf $fileName
}


function installClient()
{
	read -p "Install router client,Y or n(`greenStr "Y"`):" yesOrNo
	if [ -z $yesOrNo ] ;then
        	yesOrNo="Y"
	fi
	yesOrNo=$(echo $yesOrNo | tr '[a-z]' '[A-Z]')
	if [ $yesOrNo == "Y" ] ;then
        	installRouter client
	else
        	redStr "You choose to skip install router client"
	fi
}

function installAdmin(){

	read -p "Install router admin,Y or n(`greenStr "Y"`):" yesOrNo
	if [ -z $yesOrNo ] ;then
        	yesOrNo="Y"
	fi
	yesOrNo=$(echo $yesOrNo | tr '[a-z]' '[A-Z]')
	if [ $yesOrNo == "Y" ] ;then
        	installRouter admin
	else
        	redStr "You choose to skip install router admin"
	fi
}



function backupConfig()
 {

        yellowStr "Backup config files before install"
	serviceConfigLocation=$tomcatLocation/webapps/$serviceName/WEB-INF/classes
        for i in $configFiles
        do
                if [ -e $i ] ;then
                        rm -rf $i
                fi

                cp $serviceConfigLocation/$i ./
                if [ -e $i ] ;then
                        greenStr "Success to backup $i"
                fi
        done
}

function backupBuildConfig()
{

        yellowStr "Backup config files in war package"
        for i in $configFiles
        do
                 mv $i ${i}.build
        done
}

function copyConfig()
{
        yellowStr "Copy config files to new version"
        for i in $configFiles
        do
                configFile=$scriptLocation/$i
                if [ -e $configFile ] ;then
                        mv $configFile  ./
                else
                        redStr "No config files $i in $scriptLocation"
                fi

                if [ -e $i ] ;then
                        greenStr "Success to copy $i"
                fi
        done
}


function chkFile()
{
        flag=0
        cat $2 | grep -Ev "^\s*$|^#" >newFile
        while read line
        do
                paraName=$(echo $line | cut -d "=" -f1)
                grep "$paraName" $1 > /dev/null
                if [ $? -ne 0 ];then
                         flag=1
                        redStr "This is new Parameters,please add it with correct value to $1"
                        redStr "\t$(grep "$paraName" $2)"
                fi

        done < newFile

        rm -rf newFile
        if [ $flag -eq 0 ]
        then
                greenStr "No new parameter in $2"
        fi
}

function chkFiles()
{
        for i in $configFiles
        do
                yellowStr "Check $i whether has new parameters"
                chkFile $i ${i}.build
        done
}


function killServer()
{
        yellowStr "Stop server..."
        processPID=$(ps -Ao pid,args | grep -i $serviceName| grep -v grep |grep -v $scriptName | grep -o "^ \{0,\}[0-9]\{1,\}")
        #flag1=$?
        if [ $? -ne 0 ] ;then
                yellowStr "$serviceName is not started,so not have to stop"
                return 1
        else
                kill -9 $processPID
                sleep 5
                processPID=$(ps -Ao pid,args | grep -i $serviceName| grep -v grep |grep -v $scriptName | grep -o "^ \{0,\}[0-9]\{1,\}")
                #flag1=$?
                if [ $? -ne 0 ] ;then
                        greenStr "$serviceName is stopped"
                else
                        redStr "Fail to stop $serviceName"
                fi
        fi
}

function startServer()
{
        yellowStr "Start server..."
        processPID=$(ps -Ao pid,args | grep -i $serviceName| grep -v grep |grep -v $scriptName | grep -o "^ \{0,\}[0-9]\{1,\}")
        #flag1=$?
        if [ $? -eq 0 ] ;then
                yellowStr "$serviceName has been started"
                return
        else
                sh $tomcatLocation/bin/startup.sh >/dev/null
                processPID=$(ps -Ao pid,args | grep -i $serviceName| grep -v grep |grep -v $scriptName | grep -o "^ \{0,\}[0-9]\{1,\}")
                sleep 5
                #flag1=$?
                if [ $? -eq 0 ] ;then
                        greenStr "$serviceName is started"
                else
                        redStr "Fail to start $serviceName"
                fi
        fi

}


function installRC()
{
	yellowStr "Start to install Router Center..."
	while :
	do
		read -p "Please input tomcat path of router center(`greenStr "$tomcatLocation_def"`):" tomcatLocation
		if [ -z $tomcatLocation ] ;then
			tomcatLocation=$tomcatLocation_def
		fi
		
		if [ -d $tomcatLocation ] ;then
			break;
		else
			redStr "Tomcat path doesn't exist,please input again";
		fi
	done

        while :
        do
                read -p "Please input router center version(`greenStr "1.0.60"`):" rcVersion
                echo "$rcVersion" | grep -o "\([0-9]\{1,3\}\.\)\{2\}[0-9]\{1,3\}">/dev/null
                if [ $? -eq 0 ] ;then
                        break;
                else
                        redStr "\tRouter center version format is invaid,please input again!"
                fi
        done

	if [ $qaOrAliYun -eq 0 ] ;then
		 while :
        	 do
                	read -p "Please input url of $routerCenterFile:" warLocation
                	if [[ -z $warLocation ]] || [[ ! $warLocation =~ ^http* ]] || [[ ! $warLocation =~ ${routerCenterFile}$ ]] ;then
                       	 	redStr "The url of $routerCenterFile is invalid,please input again!"
			else
				break
                	fi

       		 done
	elif [ $qaOrAliYun -eq 1 ] ;then
		while :
		do
			read -p "Please input path of router.war(`greenStr "$tomcatLocation"`):" warLocation
			if [ -z $warLocation ] ;then
				warLocation=$tomcatLocation
			fi

			if [ -f $warLocation/router.war ] ;then
				break;
			else
				redStr "The path of router.war is invalid,please input again!"
			fi
		done
	fi

	while :
	do
		read -p "Please input service root path(`greenStr $rootPath_def`):" serviceName
		
		if [ -z $serviceName ] ;then
			serviceName=$rootPath_def
		fi
		
		echo $serviceName | grep ^$rootPath_def > /dev/null
                if [ $? -eq 0 ] ;then
                        break;
                else
                        redStr "service name should be start with router"
                fi
	done
	
	cd $scriptLocation
        backupConfig

        cd $tomcatLocation
	newFolder="webapps-build$rcVersion"
	if [ -e $newFolder ] ;then
		yellowStr "$scriptLocation/$newFolder exist!!Delete it..."
		rm -rf $newFolder
	fi
	mkdir -p $newFolder/$serviceName

        cd $newFolder/$serviceName
	if [ $qaOrAliYun -eq 0 ] ;then
		curl -s -o $routerCenterFile $warLocation
	elif [ $qaOrAliYun -eq 1 ] ;then
        	cp $warLocation/$routerCenterFile ./
	fi
	yellowStr "Uncompress $routerCenterFile"
        jar -xf $routerCenterFile
        cd WEB-INF/classes
        backupBuildConfig
        copyConfig
        chkFiles
        cd $tomcatLocation
        killServer
        ln -snf $newFolder webapps
        startServer
}

function installrc(){

        read -p "Install router center,Y or N(`greenStr "Y"`):" yesOrNo
        if [ -z $yesOrNo ] ;then
                yesOrNo="Y"
        fi
        yesOrNo=$(echo $yesOrNo | tr '[a-z]' '[A-Z]')
        if [ $yesOrNo == "Y" ] ;then
                installRC
        else
                redStr "You choose to skip install router center"
        fi
}


#Start

if [ $# -eq 0 ] ;then
	qaOrAliYun=0
elif [ $# -eq 1 ] ;then
	qaOrAliYun=$1
else
	redStr "Invalid parameters\n\t$0\n\t$0 0|1\t\t0 is QA environment,1 is Aliyun environment"
	exit
fi
if [ $qaOrAliYun -eq 0 ] ;then
	yellowStr "Install router service in QA_128 Environment!!"
elif [ $qaOrAliYun -eq 1 ] ;then
	yellowStr "Install router service in QA_Aliyun Environment!!"
else
	redStr "Environment is invalid.It should be 0 or 1\t0 is QA environment,1 is Aliyun environment"
	exit
fi

read -p "Please input nginx data path(`greenStr $nginxDataLocation_def`):" nginxDataLocation
if [ -z $nginxDataLocation ] ;then
	nginxDataLocation=$nginxDataLocation_def
fi

installClient
installAdmin
installrc
